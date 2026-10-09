import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/features/daily_routine/data/local_daily_routine_repository.dart';
import 'package:parla_con_me/features/daily_routine/domain/daily_routine.dart';
import 'package:parla_con_me/features/daily_routine/presentation/daily_routine_controller.dart';
import 'package:parla_con_me/features/daily_routine/presentation/daily_routine_screen.dart';
import 'package:parla_con_me/features/daily_routine/presentation/practice_activity.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_overview.dart';
import 'package:parla_con_me/features/learning/presentation/learning_providers.dart';
import 'package:parla_con_me/features/profile/domain/language_pair.dart';
import 'package:parla_con_me/features/progress/domain/skill_metrics.dart';
import 'package:parla_con_me/features/progress/presentation/widgets/radar_chart.dart';
import 'package:parla_con_me/features/progress/presentation/widgets/week_card.dart';
import 'package:parla_con_me/shared/ui/ui.dart';

import '../../support/in_memory_local_storage.dart';
import '../../support/learning_fixtures.dart';
import '../../support/pump_app.dart';

// The redesign of "Percorso": the days of the week that can be tapped, the
// chart of areas, the figures and the empty state. The interface is Italian.

// A Wednesday: the week is Monday 12 to Sunday 18 October 2026.
final _now = DateTime(2026, 10, 14, 12);

DailyRoutine _routine(
  String date, {
  RoutineStepState step1 = RoutineStepState.pending,
  RoutineStepState step3 = RoutineStepState.pending,
}) => DailyRoutine(
  date: date,
  learningLanguage: AppLanguage.italian,
  step1: ReviewStep(state: step1, itemIds: const ['a', 'b']),
  // A pending speaking step needs a mission; there is nothing to say here.
  step2: const ScenarioStep(state: RoutineStepState.unavailable),
  step3: VocabularyStep(state: step3, vocabularyIds: const ['it:prenotazione']),
);

/// Monday: everything done; Tuesday: nothing stored; today (Wednesday): only
/// the review.
Future<InMemoryLocalStorage> _storageWithWeek() async {
  final storage = InMemoryLocalStorage();
  final repo = LocalDailyRoutineRepository(storage);
  await repo.save(
    _routine(
      '2026-10-12',
      step1: RoutineStepState.completed,
      step3: RoutineStepState.completed,
    ),
  );
  await repo.save(_routine('2026-10-14', step1: RoutineStepState.completed));
  return storage;
}

FakeMemoryRepository _memory() => FakeMemoryRepository(
  summaryOf(
    topics: [
      topicOf(GrammarTopic.passatoProssimo, errors: 1, successes: 5),
      topicOf(GrammarTopic.articles, errors: 3),
    ],
    vocabulary: [
      wordOf('prenotazione'),
      wordOf('scontrino', exposure: 5, successes: 5),
    ],
  ),
);

Future<void> _open(
  WidgetTester tester,
  FakeMemoryRepository memory, {
  InMemoryLocalStorage? storage,
}) async {
  await pumpApp(
    tester,
    storage ?? InMemoryLocalStorage(),
    profile: onboardedProfile,
    overrides: [
      learningRepositoryProvider.overrideWithValue(memory),
      dailyRoutineClockProvider.overrideWithValue(() => _now),
    ],
  );
  tester.view.physicalSize = const Size(1080, 9000);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(AppBottomNav),
      matching: find.text('Percorso'),
    ),
  );
  await tester.pumpAndSettle();
}

/// The seven tappable days of the week card, Monday first.
Finder get _days => find.descendant(
  of: find.byType(WeekCard),
  matching: find.byType(GestureDetector),
);

void main() {
  group('the practice of the week, day by day (pure)', () {
    test('every day of the week knows its date and its routine', () {
      final monday = _routine('2026-10-12');
      final activity = practiceActivityOf(
        {'2026-10-12'},
        _now,
        routines: {'2026-10-12': monday},
      );
      expect(activity.weekStart, DateTime(2026, 10, 12));
      expect(activity.dateOf(0), DateTime(2026, 10, 12));
      expect(activity.dateOf(6), DateTime(2026, 10, 18));
      expect(activity.weekRoutines, hasLength(7));
      expect(activity.weekRoutines[0], monday);
      expect(activity.weekRoutines.skip(1), everyElement(isNull));
    });

    test('a routine of another week is not a day of this one', () {
      final activity = practiceActivityOf(
        {'2026-10-09'},
        _now,
        routines: {'2026-10-09': _routine('2026-10-09')},
      );
      expect(activity.weekRoutines, everyElement(isNull));
    });

    test('without data there is no date to show', () {
      expect(PracticeActivity.empty.dateOf(0), isNull);
      expect(PracticeActivity.empty.weekRoutines, everyElement(isNull));
    });
  });

  group('skill metrics (pure)', () {
    final activity = practiceActivityOf({'2026-10-12', '2026-10-14'}, _now);

    test('only what has evidence behind it is measured', () {
      expect(buildSkillMetrics(LearningOverview.empty, null), isEmpty);
      final onlyDays = buildSkillMetrics(LearningOverview.empty, activity);
      expect(onlyDays.map((m) => m.area), [SkillArea.consistency]);
    });

    test('vocabulary, grammar and consistency, as counts', () {
      final overview = LearningOverview(
        improving: [_topic()],
        toReinforce: [_topic(), _topic(), _topic()],
        vocabularyToConsolidate: [_word(), _word(), _word()],
        vocabularyInUse: [_word()],
      );
      final metrics = {
        for (final m in buildSkillMetrics(overview, activity)) m.area: m,
      };
      expect(metrics[SkillArea.vocabulary]!.done, 1);
      expect(metrics[SkillArea.vocabulary]!.total, 4);
      expect(metrics[SkillArea.vocabulary]!.value, 0.25);
      expect(metrics[SkillArea.grammar]!.done, 1);
      expect(metrics[SkillArea.grammar]!.total, 4);
      // Wednesday: two of the three days so far had practice.
      expect(metrics[SkillArea.consistency]!.done, 2);
      expect(metrics[SkillArea.consistency]!.total, 3);
    });

    test('nothing to count is 0, never a division by zero', () {
      expect(
        const SkillMetric(area: SkillArea.grammar, done: 0, total: 0).value,
        0,
      );
    });
  });

  group('the radar chart', () {
    Future<void> pump(WidgetTester tester, List<double> values) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 280,
                child: RadarChart(
                  values: values,
                  labels: [
                    'Vocabolario',
                    'Grammatica',
                    'Costanza',
                  ].take(values.length).toList(),
                ),
              ),
            ),
          ),
        );

    testWidgets('draws with three axes, even with a zero or an overflow', (
      tester,
    ) async {
      await pump(tester, [0, 1.4, 0.5]);
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('with fewer than three axes there is nothing to draw', (
      tester,
    ) async {
      await pump(tester, [0.5, 0.5]);
      expect(find.byType(SizedBox), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(RadarChart),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });

    testWidgets('fits a very narrow, large-text screen without overflowing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(300, 600),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: RadarChart(
                values: [0.2, 0.9, 0.5],
                labels: ['Vocabolario', 'Grammatica', 'Costanza'],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('tapping a day of the week', () {
    testWidgets('begins on today and shows what was done today', (
      tester,
    ) async {
      await _open(tester, _memory(), storage: await _storageWithWeek());
      expect(_days, findsNWidgets(7));
      // Today: only the review was done, so one step of two.
      expect(find.text('1 di 2 passi fatti'), findsOneWidget);
      expect(
        find.text('2 esercizi completati', findRichText: true),
        findsNothing,
      );
      expect(
        find.textContaining('2 esercizi completati', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('a past day shows its steps and the words it reinforced', (
      tester,
    ) async {
      await _open(tester, _memory(), storage: await _storageWithWeek());
      await tester.tap(_days.at(0)); // Monday
      await tester.pumpAndSettle();
      expect(find.text('2 di 2 passi fatti'), findsOneWidget);
      expect(
        find.textContaining('prenotazione', findRichText: true),
        findsWidgets,
      );
      // Today's summary is gone.
      expect(find.text('1 di 2 passi fatti'), findsNothing);
    });

    testWidgets('a past day without practice says so', (tester) async {
      await _open(tester, _memory(), storage: await _storageWithWeek());
      await tester.tap(_days.at(1)); // Tuesday
      await tester.pumpAndSettle();
      expect(find.text('Nessuna pratica questo giorno.'), findsOneWidget);
    });

    testWidgets('a day that has not come yet says so', (tester) async {
      await _open(tester, _memory(), storage: await _storageWithWeek());
      await tester.tap(_days.at(4)); // Friday
      await tester.pumpAndSettle();
      expect(find.text('Questo giorno non è ancora arrivato.'), findsOneWidget);
    });

    testWidgets('tapping the chosen day again goes back to today', (
      tester,
    ) async {
      await _open(tester, _memory(), storage: await _storageWithWeek());
      await tester.tap(_days.at(0));
      await tester.pumpAndSettle();
      expect(find.text('2 di 2 passi fatti'), findsOneWidget);
      await tester.tap(_days.at(0));
      await tester.pumpAndSettle();
      expect(find.text('1 di 2 passi fatti'), findsOneWidget);
    });

    testWidgets('today with no practice invites to practice', (tester) async {
      await _open(tester, _memory());
      expect(
        find.text('Oggi non hai ancora praticato. È un buon momento!'),
        findsOneWidget,
      );
    });

    testWidgets('each day is a button that says its state', (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(tester, _memory(), storage: await _storageWithWeek());
      expect(
        find.bySemanticsLabel(RegExp('^lunedì 12 ottobre 2026: 2 di 2 passi')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('martedì 13 ottobre 2026: Nessuna')),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });

  group('areas and figures', () {
    testWidgets('the radar and one line in words for each area', (
      tester,
    ) async {
      await _open(tester, _memory(), storage: await _storageWithWeek());
      expect(find.text('Le tue aree'), findsOneWidget);
      expect(find.byType(RadarChart), findsOneWidget);
      expect(find.text('1 di 2 parole in uso'), findsOneWidget);
      expect(find.text('1 di 2 aree in miglioramento'), findsOneWidget);
      // Wednesday: Monday and Wednesday of the three days so far.
      expect(
        find.text('2 di 3 giorni di pratica questa settimana'),
        findsOneWidget,
      );
      expect(
        find.text('Con più pratica compariranno altre aree.'),
        findsNothing,
      );
    });

    testWidgets('with few areas: the list, a note, and no empty radar', (
      tester,
    ) async {
      await _open(
        tester,
        FakeMemoryRepository(
          summaryOf(topics: [topicOf(GrammarTopic.articles, errors: 3)]),
        ),
      );
      expect(find.text('Le tue aree'), findsOneWidget);
      expect(find.byType(RadarChart), findsNothing);
      expect(
        find.text('Con più pratica compariranno altre aree.'),
        findsOneWidget,
      );
    });

    testWidgets('the figures are cards with an icon; the streak only if any', (
      tester,
    ) async {
      await _open(tester, _memory());
      expect(find.text('Parole incontrate'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_outlined), findsWidgets);
      expect(find.text('Giorni di fila'), findsNothing, reason: 'no streak');

      await tester.pumpWidget(const SizedBox());
      final storage = InMemoryLocalStorage();
      final repo = LocalDailyRoutineRepository(storage);
      for (final date in ['2026-10-13', '2026-10-14']) {
        await repo.save(_routine(date, step1: RoutineStepState.completed));
      }
      await _open(tester, _memory(), storage: storage);
      expect(find.text('Giorni di fila'), findsOneWidget);
    });
  });

  group('empty state', () {
    testWidgets('a picture, a friendly message and two ways to start', (
      tester,
    ) async {
      await _open(tester, FakeMemoryRepository());
      expect(find.text('Stiamo iniziando a conoscerti.'), findsOneWidget);
      expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
      expect(find.widgetWithText(PrimaryButton, 'Parliamo'), findsOneWidget);
      // The week is there from the first day, with nothing invented.
      expect(find.text('Questa settimana'), findsOneWidget);
      expect(find.byType(RadarChart), findsNothing);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('the second way leads to the practice of the day', (
      tester,
    ) async {
      await _open(tester, FakeMemoryRepository());
      await tester.tap(
        find.widgetWithText(PrimaryButton, 'Fai la pratica di oggi'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DailyRoutineScreen), findsOneWidget);
    });
  });
}

TopicView _topic() => const TopicView(
  topic: GrammarTopic.articles,
  standing: TopicStanding.toReinforce,
  successfulUses: 0,
  appearances: 1,
);

VocabularyView _word() => const VocabularyView(
  word: 'x',
  language: 'it',
  successfulUses: 0,
  isConsolidated: false,
);
