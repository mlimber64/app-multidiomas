import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/features/daily_routine/domain/daily_routine.dart';
import 'package:parla_con_me/features/profile/domain/language_pair.dart';
import 'package:parla_con_me/features/reminders/domain/reminder_plan.dart';

// A Wednesday. The goal reminder is at 15:00 and the streak one at 20:30.
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 10, day, hour, minute);

DailyRoutine routine({
  RoutineStepState step1 = RoutineStepState.pending,
  RoutineStepState step3 = RoutineStepState.unavailable,
}) => DailyRoutine(
  date: '2026-10-14',
  learningLanguage: AppLanguage.italian,
  step1: ReviewStep(state: step1, itemIds: const ['a']),
  step2: const ScenarioStep(state: RoutineStepState.unavailable),
  step3: VocabularyStep(state: step3),
);

final done = routine(step1: RoutineStepState.completed);
final pending = routine();
const nothing = DailyRoutine(
  date: '2026-10-14',
  learningLanguage: AppLanguage.italian,
  step1: ReviewStep(state: RoutineStepState.unavailable),
  step2: ScenarioStep(state: RoutineStepState.unavailable),
  step3: VocabularyStep(state: RoutineStepState.unavailable),
);

List<PlannedReminder> plan({
  required DateTime now,
  required DailyRoutine today,
  int streak = 0,
  bool practicedToday = false,
  ReminderSchedule schedule = const ReminderSchedule(),
}) => planReminders(
  ReminderContext(
    now: now,
    routine: today,
    streak: streak,
    practicedToday: practicedToday,
  ),
  schedule: schedule,
);

List<DateTime> times(List<PlannedReminder> p, ReminderKind kind) => [
  for (final r in p)
    if (r.kind == kind) r.at,
];

void main() {
  group('the goal reminder (afternoon)', () {
    test('goes out every day of the horizon while today is not done', () {
      final p = plan(now: at(14, 10), today: pending);
      expect(times(p, ReminderKind.goal), [at(14, 15), at(15, 15), at(16, 15)]);
    });

    test('is not sent today once the routine is complete', () {
      final p = plan(now: at(14, 10), today: done);
      // Nothing for today; the next days keep theirs.
      expect(times(p, ReminderKind.goal), [at(15, 15), at(16, 15)]);
    });

    test('a routine with only some steps done is not complete', () {
      final partial = routine(
        step1: RoutineStepState.completed,
        step3: RoutineStepState.pending,
      );
      expect(partial.status, isNot(RoutineStatus.completed));
      expect(
        times(plan(now: at(14, 10), today: partial), ReminderKind.goal),
        contains(at(14, 15)),
      );
    });

    test('a time that has passed is not scheduled', () {
      final p = plan(now: at(14, 16), today: pending);
      expect(times(p, ReminderKind.goal), [at(15, 15), at(16, 15)]);
    });

    test('with nothing to practice there is nothing to remind', () {
      expect(plan(now: at(14, 10), today: nothing, streak: 5), isEmpty);
    });

    test('the horizon limits how far ahead it goes', () {
      final p = plan(
        now: at(14, 10),
        today: pending,
        schedule: const ReminderSchedule(horizonDays: 1),
      );
      expect(times(p, ReminderKind.goal), [at(14, 15)]);
    });

    test('the times can be changed', () {
      final p = plan(
        now: at(14, 8),
        today: pending,
        schedule: const ReminderSchedule(goalTime: ReminderTime(9, 30)),
      );
      expect(times(p, ReminderKind.goal).first, at(14, 9, 30));
    });
  });

  group('the streak reminder (night)', () {
    test('goes out tonight when the streak is alive and nothing is done', () {
      final p = plan(now: at(14, 10), today: pending, streak: 4);
      final streak = p.where((r) => r.kind == ReminderKind.streak).toList();
      expect(streak, hasLength(1));
      expect(streak.single.at, at(14, 20, 30));
      expect(streak.single.streak, 4);
    });

    test('is not sent with no streak', () {
      final p = plan(now: at(14, 10), today: pending);
      expect(times(p, ReminderKind.streak), isEmpty);
    });

    test('is not sent once the routine is complete', () {
      final p = plan(
        now: at(14, 10),
        today: done,
        streak: 4,
        practicedToday: true,
      );
      expect(times(p, ReminderKind.streak).where((t) => t.day == 14), isEmpty);
    });

    test('is not sent if today already counts for the streak', () {
      // A step is done (the day counts) but the routine is not complete: the
      // streak is safe tonight; the goal reminder still nudges.
      final partial = routine(
        step1: RoutineStepState.completed,
        step3: RoutineStepState.pending,
      );
      final p = plan(
        now: at(14, 10),
        today: partial,
        streak: 4,
        practicedToday: true,
      );
      expect(times(p, ReminderKind.streak).where((t) => t.day == 14), isEmpty);
      expect(times(p, ReminderKind.goal), contains(at(14, 15)));
    });

    test('tomorrow night is planned only if today already counts', () {
      final counted = plan(
        now: at(14, 10),
        today: done,
        streak: 4,
        practicedToday: true,
      );
      expect(times(counted, ReminderKind.streak), [at(15, 20, 30)]);
      expect(
        counted.firstWhere((r) => r.kind == ReminderKind.streak).streak,
        4,
      );

      // Not counted yet: if today is missed the streak is lost, so there will
      // be nothing to protect tomorrow night.
      final notCounted = plan(now: at(14, 10), today: pending, streak: 4);
      expect(times(notCounted, ReminderKind.streak), [at(14, 20, 30)]);
    });

    test('a time that has passed is not scheduled', () {
      final p = plan(now: at(14, 21), today: pending, streak: 4);
      expect(times(p, ReminderKind.streak), isEmpty);
    });
  });

  group('the plan', () {
    test('is in order and every notification has its own stable id', () {
      final p = plan(now: at(14, 10), today: pending, streak: 2);
      expect(p.map((r) => r.at).toList(), [...p.map((r) => r.at)]..sort());
      expect(p.map((r) => r.id).toSet(), hasLength(p.length));
      // The same reminder always has the same id: scheduling it again
      // replaces it instead of piling up.
      final again = plan(now: at(14, 11), today: pending, streak: 2);
      expect(p.map((r) => r.id), again.map((r) => r.id));
      expect(reminderId(at(14, 15), ReminderKind.goal), 202610141);
      expect(reminderId(at(14, 15), ReminderKind.streak), 202610142);
    });

    test('the payload says which reminder was tapped', () {
      final p = plan(now: at(14, 10), today: pending, streak: 2);
      expect(p.map((r) => r.payload).toSet(), {'goal', 'streak'});
    });

    test('ids fit the 32 bits of an Android notification id', () {
      final id = reminderId(DateTime(2099, 12, 31), ReminderKind.streak);
      expect(id, lessThan(2147483647));
    });
  });
}
