import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/features/daily_routine/data/local_daily_routine_repository.dart';
import 'package:parla_con_me/features/daily_routine/domain/daily_routine.dart';
import 'package:parla_con_me/features/daily_routine/domain/scenario_mission.dart';
import 'package:parla_con_me/features/daily_routine/presentation/daily_routine_controller.dart';
import 'package:parla_con_me/features/daily_routine/presentation/daily_routine_screen.dart';
import 'package:parla_con_me/features/daily_routine/presentation/widgets/routine_card.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/user_vocabulary.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/shared/ui/ui.dart';

import '../../support/fake_ai_service.dart';
import '../../support/in_memory_local_storage.dart';
import '../../support/pump_app.dart';

Future<InMemoryLocalStorage> _storage({bool memory = true}) async {
  final storage = InMemoryLocalStorage();
  if (!memory) return storage;
  final learning = LocalLearningRepository(storage);
  for (var i = 0; i < 2; i++) {
    await learning.recordError(
      LearningError(
        id: 'ho andato -> sono andato',
        category: LearningErrorCategory.grammar,
        original: 'ho andato',
        corrected: 'sono andato',
        explanation: 'Usiamo "essere" con andare.',
        firstSeenAt: DateTime.now(),
        lastSeenAt: DateTime.now(),
        confidence: 0.9,
        grammarTopic: GrammarTopic.essereVsAvere,
      ),
    );
  }
  await learning.recordVocabulary(
    UserVocabulary.of(word: 'ciao', at: DateTime.now()),
  );
  return storage;
}

Future<DailyRoutine> _stored(InMemoryLocalStorage storage) async {
  final result = await LocalDailyRoutineRepository(
    storage,
  ).load(DailyRoutine.dateOf(DateTime.now()), AppLanguage.italian);
  return result.when(success: (v) => v!, failure: (f) => throw f);
}

/// Plans today's routine once, then restarts the app with [change] applied to
/// it, over the same storage.
Future<void> _pumpWith(
  WidgetTester tester,
  InMemoryLocalStorage storage, {
  DailyRoutine Function(DailyRoutine planned)? change,
  UserLearningProfile profile = onboardedProfile,
  List<Override> overrides = const [],
}) async {
  await pumpApp(tester, storage, profile: profile, overrides: overrides);
  if (change == null) return;
  final planned = await _stored(storage);
  await LocalDailyRoutineRepository(storage).save(change(planned));
  await tester.pumpWidget(const SizedBox());
  await pumpApp(tester, storage, profile: profile, overrides: overrides);
}

Finder get _card => find.byType(RoutineCard);
Finder _inCard(Finder f) => find.descendant(of: _card, matching: f);
// El botón principal de la tarjeta (el hero) y su etiqueta.
Finder get _button => _inCard(find.byType(PrimaryButton));
Finder _cta(String label) => _inCard(find.widgetWithText(PrimaryButton, label));

DailyRoutine _step2(DailyRoutine r) => r.completeStep1()!;

/// Step 2 whose mission names a topic, as one from a learner with a real weak
/// topic does.
DailyRoutine _step2WithTopic(DailyRoutine r) {
  final next = r.completeStep1()!;
  final mission = next.step2.mission!;
  return DailyRoutine(
    date: next.date,
    learningLanguage: next.learningLanguage,
    step1: next.step1,
    step2: ScenarioStep(
      state: next.step2.state,
      mission: ScenarioMission(
        id: mission.id,
        situation: mission.situation,
        learningLanguage: mission.learningLanguage,
        targetTopics: const [GrammarTopic.essereVsAvere],
        prompt: mission.prompt,
      ),
    ),
    step3: next.step3,
  );
}

DailyRoutine _step3(DailyRoutine r) => r.completeStep1()!.completeStep2()!;
DailyRoutine _done(DailyRoutine r) =>
    r.completeStep1()!.completeStep2()!.completeStep3()!;

class _FailingRoutine extends DailyRoutineController {
  @override
  Future<DailyRoutine> build() async => throw Exception('no routine');
}

class _LoadingRoutine extends DailyRoutineController {
  @override
  Future<DailyRoutine> build() => Completer<DailyRoutine>().future;
}

void main() {
  testWidgets('not started: reason, step and CTA are the review\'s', (
    tester,
  ) async {
    await _pumpWith(tester, await _storage());
    expect(_inCard(find.text('LA TUA PRATICA DI OGGI')), findsOneWidget);
    expect(_inCard(find.text('Ripassa quello che hai visto')), findsOneWidget);
    expect(_inCard(find.text('Hai 1 esercizio da ripassare.')), findsOneWidget);
    expect(_cta('Inizia la pratica'), findsOneWidget);
    expect(_inCard(find.text('Ripassa')), findsOneWidget);
    expect(_inCard(find.text('0/3')), findsOneWidget);
    expect(_inCard(find.text('Consolida')), findsOneWidget);
  });

  testWidgets('step 1 CTA opens the real review session', (tester) async {
    await _pumpWith(tester, await _storage());
    await tester.tap(_cta('Inizia la pratica'));
    await tester.pumpAndSettle();
    expect(find.text('Correggi la frase'), findsOneWidget);
    expect(find.byType(DailyRoutineScreen), findsNothing);
  });

  testWidgets('step 2: topic reason, and the CTA opens the mission', (
    tester,
  ) async {
    final ai = FakeAIService();
    await _pumpWith(
      tester,
      await _storage(),
      change: _step2WithTopic,
      overrides: [aiServiceProvider.overrideWithValue(ai)],
    );
    expect(
      _inCard(find.textContaining('Oggi lavoriamo ancora su')),
      findsOneWidget,
    );
    expect(_inCard(find.text('Parla con il tuo insegnante')), findsOneWidget);
    expect(_cta('Continua la pratica'), findsOneWidget);
    expect(_inCard(find.text('1/3')), findsOneWidget);

    await tester.tap(_button);
    await tester.pumpAndSettle();
    expect(find.textContaining('Missione:'), findsOneWidget);
    expect(find.byType(DailyRoutineScreen), findsNothing);
    expect(ai.requests, hasLength(1), reason: 'the mission opens once');
  });

  testWidgets('step 2 without topics: the goal explains the mission', (
    tester,
  ) async {
    await _pumpWith(tester, await _storage(memory: false));
    expect(
      _inCard(find.textContaining('Continuiamo a lavorare sul tuo obiettivo')),
      findsOneWidget,
    );
  });

  testWidgets('step 3: words reason, and the CTA opens the real words', (
    tester,
  ) async {
    await _pumpWith(tester, await _storage(), change: _step3);
    expect(_inCard(find.text('Hai 1 parola da consolidare.')), findsOneWidget);
    expect(_inCard(find.text('Consolida le tue parole')), findsOneWidget);
    await tester.tap(_cta('Continua la pratica'));
    await tester.pumpAndSettle();
    expect(find.text('ciao'), findsOneWidget);
    expect(find.byType(DailyRoutineScreen), findsNothing);
  });

  testWidgets('completed: "Pratica completata", overview still opens', (
    tester,
  ) async {
    await _pumpWith(tester, await _storage(), change: _done);
    expect(_inCard(find.text('Pratica completata')), findsOneWidget);
    expect(_inCard(find.text('3/3')), findsOneWidget);
    await tester.tap(_button);
    await tester.pumpAndSettle();
    expect(find.byType(DailyRoutineScreen), findsOneWidget);
  });

  testWidgets('the card itself still opens the full routine', (tester) async {
    await _pumpWith(tester, await _storage());
    await tester.tap(_inCard(find.text('Ripassa quello che hai visto')));
    await tester.pumpAndSettle();
    expect(find.byType(DailyRoutineScreen), findsOneWidget);
  });

  testWidgets('empty routine: no guidance, only the overview', (tester) async {
    await _pumpWith(
      tester,
      await _storage(),
      change: (r) => DailyRoutine(
        date: r.date,
        learningLanguage: r.learningLanguage,
        step1: const ReviewStep(state: RoutineStepState.unavailable),
        step2: const ScenarioStep(state: RoutineStepState.unavailable),
        step3: const VocabularyStep(state: RoutineStepState.unavailable),
      ),
    );
    expect(_inCard(find.text('La tua pratica di oggi')), findsOneWidget);
    expect(_cta('Inizia la pratica'), findsOneWidget);
  });

  testWidgets('loading: nothing is shown on Home', (tester) async {
    await pumpApp(
      tester,
      await _storage(),
      profile: onboardedProfile,
      overrides: [dailyRoutineProvider.overrideWith(_LoadingRoutine.new)],
    );
    expect(_inCard(find.byType(Text)), findsNothing);
  });

  testWidgets('error: message and retry, no CTA', (tester) async {
    await pumpApp(
      tester,
      await _storage(),
      profile: onboardedProfile,
      overrides: [dailyRoutineProvider.overrideWith(_FailingRoutine.new)],
    );
    expect(_inCard(find.byType(PrimaryButton)), findsNothing);
    expect(_inCard(find.text('Riprova')), findsOneWidget);
  });

  testWidgets('English interface', (tester) async {
    await _pumpWith(
      tester,
      await _storage(),
      profile: onboardedProfile.copyWith(uiLanguage: AppLanguage.english),
    );
    expect(_inCard(find.text('YOUR PRACTICE FOR TODAY')), findsOneWidget);
    expect(
      _inCard(find.text('You have 1 exercise to review.')),
      findsOneWidget,
    );
    expect(_cta('Start practice'), findsOneWidget);
  });

  testWidgets('Spanish interface, narrow width, large text: no overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpWith(
      tester,
      await _storage(),
      profile: onboardedProfile.copyWith(uiLanguage: AppLanguage.spanish),
    );
    expect(
      _inCard(find.text('Tienes 1 ejercicio para repasar.')),
      findsOneWidget,
    );
    expect(_cta('Empezar práctica'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('step indicators are readable by a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpWith(tester, await _storage(), change: _step2);
    expect(find.bySemanticsLabel(RegExp('Ripassa: fatto')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Parla: da fare')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Consolida: da fare')), findsOneWidget);
    final size = tester.getSize(_button);
    expect(size.height, greaterThanOrEqualTo(48));
    handle.dispose();
  });

  testWidgets('rebuilding Home writes nothing and asks the AI nothing', (
    tester,
  ) async {
    final ai = FakeAIService();
    final storage = await _storage();
    await _pumpWith(
      tester,
      storage,
      overrides: [aiServiceProvider.overrideWithValue(ai)],
    );
    final before = Map.of(storage.data);

    // Away to the overview and back, several times.
    for (var i = 0; i < 3; i++) {
      await tester.tap(_inCard(find.text('Ripassa quello che hai visto')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    expect(storage.data, before, reason: 'no routine, review or memory write');
    expect(ai.requests, isEmpty);
  });
}
