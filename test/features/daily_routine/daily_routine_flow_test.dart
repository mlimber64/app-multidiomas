import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/features/daily_routine/data/local_daily_routine_repository.dart';
import 'package:parla_con_me/features/daily_routine/domain/daily_routine.dart';
import 'package:parla_con_me/features/daily_routine/presentation/widgets/routine_card.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/user_vocabulary.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';

import '../../support/fake_ai_service.dart';
import '../../support/in_memory_local_storage.dart';
import '../../support/pump_app.dart';

Future<InMemoryLocalStorage> _storageWithMemory({
  bool errors = true,
  bool words = true,
}) async {
  final storage = InMemoryLocalStorage();
  final learning = LocalLearningRepository(storage);
  if (errors) {
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
  }
  if (words) {
    await learning.recordVocabulary(
      UserVocabulary.of(word: 'ciao', at: DateTime.now()),
    );
  }
  return storage;
}

Finder _button(String label) => find.widgetWithText(FilledButton, label);
Finder get _homeCard => find.byType(RoutineCard);

Future<void> _openRoutine(WidgetTester tester) async {
  // Toda la tarjeta hero abre la rutina completa.
  await tester.tap(
    find.descendant(
      of: _homeCard,
      matching: find.text('LA TUA PRATICA DI OGGI'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<DailyRoutine> _stored(InMemoryLocalStorage storage) async {
  final result = await LocalDailyRoutineRepository(
    storage,
  ).load(DailyRoutine.dateOf(DateTime.now()), AppLanguage.italian);
  return result.when(success: (v) => v!, failure: (f) => throw f);
}

void main() {
  testWidgets('Home shows the real routine: progress and "Inizia"', (
    tester,
  ) async {
    final storage = await _storageWithMemory();
    await pumpApp(tester, storage, profile: onboardedProfile);

    expect(_homeCard, findsOneWidget);
    expect(
      find.descendant(
        of: _homeCard,
        matching: find.text('LA TUA PRATICA DI OGGI'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _homeCard, matching: find.text('0/3')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _homeCard, matching: find.text('Inizia la pratica')),
      findsOneWidget,
    );
    expect(storage.data['daily_routine'], isNotNull, reason: 'planned once');
  });

  testWidgets('with nothing learned yet only the conversation is offered', (
    tester,
  ) async {
    final storage = await _storageWithMemory(errors: false, words: false);
    await pumpApp(tester, storage, profile: onboardedProfile);
    expect(
      find.descendant(of: _homeCard, matching: find.text('0/1')),
      findsOneWidget,
    );

    await _openRoutine(tester);
    expect(find.text('Oggi non c’è niente da ripassare.'), findsOneWidget);
    expect(
      find.text('Oggi non ci sono parole da consolidare.'),
      findsOneWidget,
    );
    expect(find.text('Fatto'), findsNothing);
    expect(_button('Inizia'), findsOneWidget, reason: 'goes to the mission');
  });

  testWidgets('the steps unlock in order, with the real flows', (tester) async {
    final storage = await _storageWithMemory();
    final ai = FakeAIService();
    await pumpApp(
      tester,
      storage,
      profile: onboardedProfile,
      overrides: [aiServiceProvider.overrideWithValue(ai)],
    );
    await _openRoutine(tester);

    // The routine screen: three steps, only the first one open.
    expect(find.text('1. Ripassa'), findsOneWidget);
    expect(find.text('2. Parla'), findsOneWidget);
    expect(find.text('3. Consolida'), findsOneWidget);
    expect(find.text('1 esercizio da ripassare'), findsOneWidget);
    expect(find.text('Prima completa il passo precedente.'), findsNWidgets(2));
    expect(_button('Inizia'), findsOneWidget);

    // Step 1: the real review, limited to the routine's item.
    await tester.tap(_button('Inizia'));
    await tester.pumpAndSettle();
    expect(find.text('Correggi la frase'), findsOneWidget);
    expect(find.text('1 di 1'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'sono andato');
    await tester.pump();
    await tester.tap(_button('Controlla'));
    await tester.pumpAndSettle();
    await tester.tap(_button('Continua'));
    await tester.pumpAndSettle();
    await tester.tap(_button('Continua la pratica'));
    await tester.pumpAndSettle();

    expect(find.text('Fatto'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('Prima completa il passo precedente.'), findsOneWidget);
    expect((await _stored(storage)).step1.state, RoutineStepState.completed);

    // Step 2: the usual conversation, opened by the teacher.
    await tester.tap(_button('Continua'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Missione:'), findsOneWidget);
    expect(find.text('Bene! E poi?'), findsOneWidget, reason: 'teacher first');
    expect(ai.requests.single.messages.single.text, contains('ready'));
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Termina la missione'),
          )
          .onPressed,
      isNull,
      reason: 'not enough turns yet',
    );

    for (final line in ['Un caffè, per favore', 'E un cornetto']) {
      await tester.enterText(find.byType(TextField), line);
      await tester.pump();
      await tester.tap(find.byTooltip('Invia'));
      await tester.pumpAndSettle();
    }
    expect(ai.requests, hasLength(3), reason: 'one call per message, no extra');
    await tester.tap(find.widgetWithText(FilledButton, 'Termina la missione'));
    await tester.pumpAndSettle();

    expect(find.text('2/3'), findsOneWidget);
    expect((await _stored(storage)).step2.state, RoutineStepState.completed);

    // Step 3: the words.
    await tester.tap(_button('Continua'));
    await tester.pumpAndSettle();
    expect(find.text('ciao'), findsOneWidget);
    await tester.tap(_button('Ho finito'));
    await tester.pumpAndSettle();

    expect(find.text('Completata! 🎉'), findsOneWidget);
    expect(find.text('3/3'), findsOneWidget);
    expect((await _stored(storage)).isComplete, isTrue);
  });

  testWidgets('leaving a step without finishing it does not complete it', (
    tester,
  ) async {
    final storage = await _storageWithMemory();
    await pumpApp(tester, storage, profile: onboardedProfile);
    await _openRoutine(tester);
    await tester.tap(_button('Inizia'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Fatto'), findsNothing);
    expect((await _stored(storage)).completedCount, 0);
  });

  testWidgets('reopening the app shows the same routine and progress', (
    tester,
  ) async {
    final storage = await _storageWithMemory();
    await pumpApp(tester, storage, profile: onboardedProfile);
    final planned = await _stored(storage);
    await LocalDailyRoutineRepository(storage).save(planned.completeStep1()!);

    // A new launch over the same storage.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, storage, profile: onboardedProfile);
    expect(
      find.descendant(of: _homeCard, matching: find.text('1/3')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _homeCard,
        matching: find.text('Continua la pratica'),
      ),
      findsOneWidget,
    );
    expect((await _stored(storage)).step2.mission, planned.step2.mission);
  });
}
