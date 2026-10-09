import '../../daily_routine/domain/daily_routine.dart';

/// The two daily reminders.
enum ReminderKind {
  /// Afternoon nudge: today's practice is still to do.
  goal,

  /// Night nudge: the streak is alive but today has no practice yet.
  streak,
}

/// A time of day (no date, no zone): when a reminder goes out.
class ReminderTime {
  const ReminderTime(this.hour, this.minute);

  final int hour;
  final int minute;

  /// This time on the calendar day of [day], in the device's zone.
  DateTime on(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);
}

/// When the reminders go out and how far ahead they are planned.
class ReminderSchedule {
  const ReminderSchedule({
    this.goalTime = const ReminderTime(15, 0),
    this.streakTime = const ReminderTime(20, 30),
    this.horizonDays = 3,
  });

  final ReminderTime goalTime;
  final ReminderTime streakTime;

  /// How many days (today included) get a goal reminder. A reminder for a
  /// future day is only a promise that "if nothing is done by then, nudge": it
  /// is replaced the moment the app learns more. Capping it keeps someone who
  /// stopped opening the app from being nudged for ever.
  final int horizonDays;
}

/// One notification to schedule.
class PlannedReminder {
  const PlannedReminder({
    required this.kind,
    required this.at,
    this.streak = 0,
  });

  final ReminderKind kind;

  /// Local date and time it goes out.
  final DateTime at;

  /// The streak the text mentions (only for [ReminderKind.streak]).
  final int streak;

  /// Stable id for the notification: the day and the kind, so the same
  /// reminder always has the same id (`20261014` + `1`).
  int get id => reminderId(at, kind);

  /// What the app gets back when the notification is tapped.
  String get payload => kind.name;

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.kind == kind &&
      other.at == at &&
      other.streak == streak;

  @override
  int get hashCode => Object.hash(kind, at, streak);

  @override
  String toString() => 'PlannedReminder($kind, $at, streak: $streak)';
}

/// `yyyymmdd` × 10 + the kind: fits an Android notification id (32 bits).
int reminderId(DateTime day, ReminderKind kind) =>
    (day.year * 10000 + day.month * 100 + day.day) * 10 + kind.index + 1;

/// What the planner needs to know about the learner right now.
class ReminderContext {
  const ReminderContext({
    required this.now,
    required this.routine,
    required this.streak,
    required this.practicedToday,
  });

  final DateTime now;

  /// Today's routine.
  final DailyRoutine routine;

  /// Days in a row with practice (see `PracticeActivity.streak`): up to today
  /// if today has practice, up to yesterday if not.
  final int streak;

  /// At least one step of today's routine is done, so today already counts
  /// for the streak.
  final bool practicedToday;
}

/// Pure: the reminders worth scheduling, earliest first.
///
/// - **Goal** (afternoon): every day of the horizon whose time is still ahead,
///   except today when today's routine is complete. Nothing to practice today
///   (an empty routine) means nothing to remind.
/// - **Streak** (night): only when the streak is really at risk. Today: the
///   streak is above 0 and nothing has been practiced yet today. Tomorrow: only
///   if today already counts, so the streak will still be alive tomorrow night
///   (if today is missed the streak is gone and there is nothing to protect).
///
/// The app cannot run code when a notification is due, so the conditions are
/// decided now, when scheduling; whatever changes them (a step done, a new
/// day, the app opened) schedules again.
List<PlannedReminder> planReminders(
  ReminderContext context, {
  ReminderSchedule schedule = const ReminderSchedule(),
}) {
  final routine = context.routine;
  if (routine.isEmpty) return const [];
  final today = DateTime(context.now.year, context.now.month, context.now.day);
  final doneToday = routine.status == RoutineStatus.completed;

  final plan = <PlannedReminder>[];
  for (var offset = 0; offset < schedule.horizonDays; offset++) {
    final day = DateTime(today.year, today.month, today.day + offset);

    if (!(offset == 0 && doneToday)) {
      final at = schedule.goalTime.on(day);
      if (at.isAfter(context.now)) {
        plan.add(PlannedReminder(kind: ReminderKind.goal, at: at));
      }
    }

    final atRisk = switch (offset) {
      0 => context.streak > 0 && !context.practicedToday,
      1 => context.practicedToday && context.streak > 0,
      _ => false,
    };
    if (atRisk) {
      final at = schedule.streakTime.on(day);
      if (at.isAfter(context.now)) {
        plan.add(
          PlannedReminder(
            kind: ReminderKind.streak,
            at: at,
            streak: context.streak,
          ),
        );
      }
    }
  }
  plan.sort((a, b) => a.at.compareTo(b.at));
  return plan;
}
