import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/theme/app_tokens.dart';
import 'package:parla_con_me/features/daily_routine/data/local_daily_routine_repository.dart';
import 'package:parla_con_me/features/daily_routine/domain/daily_routine.dart';
import 'package:parla_con_me/features/daily_routine/presentation/daily_routine_controller.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/presentation/learning_providers.dart';
import 'package:parla_con_me/features/profile/domain/achievements.dart';
import 'package:parla_con_me/features/profile/domain/language_pair.dart';
import 'package:parla_con_me/features/profile/presentation/widgets/achievements_card.dart';
import 'package:parla_con_me/shared/models/voice_gender.dart';
import 'package:parla_con_me/shared/ui/ui.dart';

import '../../support/in_memory_local_storage.dart';
import '../../support/learning_fixtures.dart';
import '../../support/pump_app.dart';

// The redesign of "Profilo": grouped settings with icons, the medals, the
// voice controls and the quiet footer. The interface of these tests is Italian.

// A Wednesday: the week is Monday 12 to Sunday 18 October 2026.
final _now = DateTime(2026, 10, 14, 12);

DailyRoutine _routine(
  String date, {
  RoutineStepState step1 = RoutineStepState.pending,
  RoutineStepState step3 = RoutineStepState.pending,
}) => DailyRoutine(
  date: date,
  learningLanguage: AppLanguage.italian,
  step1: ReviewStep(state: step1, itemIds: const ['a']),
  // A pending speaking step needs a mission; there is nothing to say here.
  step2: const ScenarioStep(state: RoutineStepState.unavailable),
  step3: VocabularyStep(state: step3, vocabularyIds: const ['it:ciao']),
);

Future<void> _open(
  WidgetTester tester, {
  FakeMemoryRepository? memory,
  InMemoryLocalStorage? storage,
}) async {
  await pumpApp(
    tester,
    storage ?? InMemoryLocalStorage(),
    profile: onboardedProfile,
    overrides: [
      learningRepositoryProvider.overrideWithValue(
        memory ?? FakeMemoryRepository(),
      ),
      dailyRoutineClockProvider.overrideWithValue(() => _now),
    ],
  );
  tester.view.physicalSize = const Size(1080, 9000);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(AppBottomNav),
      matching: find.text('Profilo'),
    ),
  );
  await tester.pumpAndSettle();
}

/// Monday: all done; Tuesday and today: only the review. That is a streak of
/// three days and a day with every step done.
Future<InMemoryLocalStorage> _storageWithStreak() async {
  final storage = InMemoryLocalStorage();
  final repo = LocalDailyRoutineRepository(storage);
  await repo.save(
    _routine(
      '2026-10-12',
      step1: RoutineStepState.completed,
      step3: RoutineStepState.completed,
    ),
  );
  for (final date in ['2026-10-13', '2026-10-14']) {
    await repo.save(_routine(date, step1: RoutineStepState.completed));
  }
  return storage;
}

FakeMemoryRepository _memory() => FakeMemoryRepository(
  summaryOf(
    topics: [topicOf(GrammarTopic.passatoProssimo, errors: 1, successes: 5)],
    vocabulary: [
      wordOf('prenotazione'),
      wordOf('scontrino', exposure: 5, successes: 5),
    ],
  ),
);

void main() {
  group('achievements (pure)', () {
    test('nothing is unlocked with no evidence', () {
      expect(unlockedAchievements(AchievementStats.none), isEmpty);
    });

    test('each medal opens with one plain fact', () {
      bool unlocked(Achievement a, AchievementStats s) => a.isUnlocked(s);
      expect(
        unlocked(
          Achievement.firstSteps,
          const AchievementStats(hasMemory: true),
        ),
        isTrue,
      );
      expect(
        unlocked(
          Achievement.firstSteps,
          const AchievementStats(practicedThisWeek: 1),
        ),
        isTrue,
      );
      expect(
        unlocked(Achievement.streak3, const AchievementStats(streak: 2)),
        isFalse,
      );
      expect(
        unlocked(Achievement.streak3, const AchievementStats(streak: 3)),
        isTrue,
      );
      expect(
        unlocked(Achievement.streak7, const AchievementStats(streak: 7)),
        isTrue,
      );
      expect(
        unlocked(
          Achievement.fullDay,
          const AchievementStats(fullPracticeDay: true),
        ),
        isTrue,
      );
      expect(
        unlocked(Achievement.firstWord, const AchievementStats(wordsInUse: 1)),
        isTrue,
      );
      // Met is not the same as in use: ten words met opens a different medal.
      expect(
        unlocked(Achievement.firstWord, const AchievementStats(wordsMet: 10)),
        isFalse,
      );
      expect(
        unlocked(Achievement.words10, const AchievementStats(wordsMet: 10)),
        isTrue,
      );
      expect(
        unlocked(
          Achievement.improving1,
          const AchievementStats(areasImproving: 1),
        ),
        isTrue,
      );
      expect(
        unlocked(
          Achievement.improving3,
          const AchievementStats(areasImproving: 2),
        ),
        isFalse,
      );
    });

    test('the unlocked ones keep the display order', () {
      final list = unlockedAchievements(
        const AchievementStats(
          streak: 7,
          hasMemory: true,
          areasImproving: 3,
          wordsInUse: 2,
          wordsMet: 12,
        ),
      );
      expect(list, [
        Achievement.firstSteps,
        Achievement.streak3,
        Achievement.streak7,
        Achievement.firstWord,
        Achievement.words10,
        Achievement.improving1,
        Achievement.improving3,
      ]);
    });
  });

  group('the settings, grouped', () {
    testWidgets('three groups with their title and an icon on every row', (
      tester,
    ) async {
      await _open(tester);
      expect(find.text('LINGUE'), findsOneWidget);
      expect(find.text('COME IMPARI'), findsOneWidget);
      expect(find.text('VOCE'), findsOneWidget);
      expect(find.byType(SettingsList), findsNWidgets(2));
      expect(find.byType(SettingsRow), findsNWidgets(6));
      for (final row in tester.widgetList<SettingsRow>(
        find.byType(SettingsRow),
      )) {
        expect(row.icon, isNotNull, reason: row.label);
      }
    });

    testWidgets('a row still opens its editor and saves the choice', (
      tester,
    ) async {
      final storage = InMemoryLocalStorage();
      await _open(tester, storage: storage);
      await tester.tap(find.text('Livello'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('B2 — Intermedio alto'));
      await tester.pumpAndSettle();
      expect(find.text('B2 · Intermedio alto'), findsNothing);
      expect(find.text('B2 — Intermedio alto'), findsOneWidget);
      expect(storage.data['user_learning_profile'], contains('b2'));
    });
  });

  group('voice controls', () {
    testWidgets('the voice choice has icons and a filled active state', (
      tester,
    ) async {
      await _open(tester);
      expect(find.byIcon(Icons.female), findsOneWidget);
      expect(find.byIcon(Icons.male), findsOneWidget);
      final pills = tester.widget<SegmentedPills<VoiceGender>>(
        find.byType(SegmentedPills<VoiceGender>),
      );
      expect(pills.emphasized, isTrue);
      // The chosen voice is filled green; the other one is not.
      Color? fill(String label) =>
          (tester
                      .widget<AnimatedContainer>(
                        find.ancestor(
                          of: find.text(label),
                          matching: find.byType(AnimatedContainer),
                        ),
                      )
                      .decoration!
                  as BoxDecoration)
              .color;
      await tester.ensureVisible(find.text('Maschile'));
      await tester.tap(find.text('Maschile'));
      await tester.pumpAndSettle();
      expect(fill('Maschile'), AppColors.green);
      expect(fill('Femminile'), Colors.transparent);
    });

    testWidgets('the reading-aloud switch shows its state in the thumb', (
      tester,
    ) async {
      await _open(tester);
      final tile = find.widgetWithText(
        SwitchListTile,
        'Leggi le risposte ad alta voce',
      );
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      // The thumb (painted by the switch, not a widget) shows the state.
      IconData? thumb(Set<WidgetState> states) =>
          tester.widget<SwitchListTile>(tile).thumbIcon!.resolve(states)!.icon;
      expect(thumb({}), Icons.volume_off);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
      expect(thumb({WidgetState.selected}), Icons.volume_up);
    });
  });

  group('achievements on the profile', () {
    testWidgets('with nothing yet: every medal locked and a goal shown', (
      tester,
    ) async {
      await _open(tester);
      expect(find.text('I tuoi traguardi'), findsOneWidget);
      expect(find.text('0 di 8'), findsOneWidget);
      // The first medal to win is explained.
      expect(find.text('Primi passi'), findsWidgets);
      expect(
        find.text('Pratica o conversa per la prima volta.'),
        findsOneWidget,
      );
      expect(find.text('Da sbloccare'), findsOneWidget);
    });

    testWidgets('they unlock with real practice and learning', (tester) async {
      await _open(
        tester,
        memory: _memory(),
        storage: await _storageWithStreak(),
      );
      // First steps, a streak of three, a full day, a word in use and an area
      // improving.
      expect(find.text('5 di 8'), findsOneWidget);
      expect(
        tester.widget<AchievementsCard>(find.byType(AchievementsCard)),
        isNotNull,
      );
    });

    testWidgets('tapping a medal shows what it asks for, locked or not', (
      tester,
    ) async {
      await _open(
        tester,
        memory: _memory(),
        storage: await _storageWithStreak(),
      );
      await tester.tap(find.text('Una settimana intera').first);
      await tester.pumpAndSettle();
      expect(find.text('Pratica 7 giorni di fila.'), findsOneWidget);
      expect(find.text('Da sbloccare'), findsOneWidget);

      await tester.tap(find.text('Costante'));
      await tester.pumpAndSettle();
      expect(find.text('Pratica 3 giorni di fila.'), findsOneWidget);
      expect(find.text('Sbloccato'), findsOneWidget);
      expect(find.text('Da sbloccare'), findsNothing);
    });

    testWidgets('the medals fit a narrow screen without overflowing', (
      tester,
    ) async {
      await pumpApp(tester, InMemoryLocalStorage(), profile: onboardedProfile);
      tester.view.physicalSize = const Size(780, 9000); // 260 dp wide
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomNav),
          matching: find.text('Profilo'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('I tuoi traguardi'), findsOneWidget);
    });
  });

  testWidgets('the footer is quiet and centered', (tester) async {
    await _open(tester);
    final note = find.text('Le tue preferenze restano su questo dispositivo.');
    expect(note, findsOneWidget);
    final text = tester.widget<Text>(note);
    expect(text.textAlign, TextAlign.center);
    expect(text.style?.fontSize, lessThanOrEqualTo(12));
    final center = tester.getCenter(note).dx;
    expect(center, closeTo(tester.view.physicalSize.width / 3 / 2, 2));
  });
}
