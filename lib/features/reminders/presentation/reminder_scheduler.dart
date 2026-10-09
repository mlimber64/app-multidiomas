import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/router/app_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/notifications/notification_service.dart';
import '../../daily_routine/domain/daily_routine.dart';
import '../../daily_routine/presentation/daily_routine_controller.dart';
import '../../daily_routine/presentation/practice_activity.dart';
import '../../profile/presentation/profile_controller.dart';
import '../data/reminder_settings.dart';
import '../domain/reminder_plan.dart';

/// Whether a timer wakes the scheduler at midnight, for an app left open
/// overnight. Tests turn it off: a timer that is always pending would keep
/// them from finishing.
final reminderMidnightRefreshProvider = Provider<bool>((ref) => true);

/// Keeps the daily reminders in step with the learner's practice. Watching it
/// (the app does, once) is what starts it.
///
/// It schedules again whenever something that decides the reminders changes:
/// a step of today's routine is done (the reminders of a finished day are
/// taken away at once), the streak changes, the language or the on/off
/// setting changes, the app comes back to the foreground, and at midnight
/// (a new day). What to schedule is decided by `planReminders`; this class
/// only listens, asks for the permission and talks to the platform.
final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  final scheduler = ReminderScheduler(ref);
  ref.onDispose(scheduler.dispose);
  scheduler.start();
  return scheduler;
});

class ReminderScheduler {
  ReminderScheduler(this._ref);

  final Ref _ref;

  late final AppLifecycleListener _lifecycle;
  Timer? _midnight;
  bool _started = false;
  bool _disposed = false;

  /// Syncs run one after the other, never overlapping.
  Future<void> _tail = Future<void>.value();

  /// The learner already said no to the permission question in this session:
  /// it is not asked again until they turn the reminders on again.
  bool _permissionRefused = false;

  NotificationService get _service => _ref.read(notificationServiceProvider);

  void start() {
    if (_started) return;
    _started = true;

    // Everything that decides the reminders.
    void again(Object? _, Object? _) => requestSync();
    _ref
      ..listen(dailyRoutineProvider, again)
      ..listen(practiceActivityProvider, again)
      ..listen(
        userLearningProfileProvider.select(
          (p) => (p.onboardingCompleted, p.effectiveUiLanguage),
        ),
        again,
      )
      ..listen(remindersEnabledProvider, (previous, enabled) {
        // Turning them back on is a fresh request: ask for the permission
        // again if it was refused.
        if (enabled && previous == false) _permissionRefused = false;
        requestSync();
      });
    _lifecycle = AppLifecycleListener(onResume: requestSync);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final l = _texts();
    await _service.initialize(
      onSelected: open,
      channelName: l.reminderChannelName,
      channelDescription: l.reminderChannelDescription,
    );
    if (_disposed) return;
    // The app was opened by tapping a reminder while it was closed.
    final launched = await _service.launchPayload();
    if (launched != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => open(launched));
    }
    requestSync();
    _armMidnight();
  }

  /// Opens the practice from a tapped reminder: Home, with the day's practice
  /// above it. Nothing happens before the onboarding is done.
  void open(String? payload) {
    if (_disposed) return;
    if (!_ref.read(userLearningProfileProvider).onboardingCompleted) return;
    final router = _ref.read(routerProvider);
    router.go(AppRoutes.home);
    router.push<void>(AppRoutes.dailyRoutine);
  }

  /// Schedules again, after whatever sync is already running.
  void requestSync() {
    if (_disposed) return;
    _tail = _tail.then((_) => sync()).catchError((_) {});
  }

  /// A new day: the routine of the day is loaded and the reminders planned
  /// for it.
  void _armMidnight() {
    _midnight?.cancel();
    if (!_ref.read(reminderMidnightRefreshProvider)) return;
    final now = _ref.read(dailyRoutineClockProvider)();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now) + const Duration(seconds: 5), () {
      if (_disposed) return;
      _ref.read(dailyRoutineProvider.notifier).refreshForToday();
      requestSync();
      _armMidnight();
    });
  }

  AppLocalizations _texts() => lookupAppLocalizations(
    Locale(_ref.read(userLearningProfileProvider).effectiveUiLanguage.code),
  );

  /// Takes every scheduled reminder away and schedules what is due now. Public
  /// so tests can wait for it.
  Future<void> sync() async {
    if (_disposed) return;
    final profile = _ref.read(userLearningProfileProvider);
    final settings = _ref.read(remindersEnabledProvider.notifier);
    await settings.ready;
    final enabled = _ref.read(remindersEnabledProvider);

    // Off, or not set up yet: no reminders at all.
    if (!profile.onboardingCompleted || !enabled) {
      await _service.cancelAll();
      return;
    }

    // The routine and the streak decide the rest; until they are loaded there
    // is nothing to decide. The listeners call again when they arrive.
    final routine = _ref.read(dailyRoutineProvider).value;
    final activity = _ref.read(practiceActivityProvider).value;
    if (routine == null || activity == null) return;

    final now = _ref.read(dailyRoutineClockProvider)();
    if (routine.date != DailyRoutine.dateOf(now)) {
      // Yesterday's routine is still loaded (the app stayed open overnight).
      _ref.read(dailyRoutineProvider.notifier).refreshForToday();
      return;
    }

    if (_permissionRefused) return;
    if (!await _service.requestPermission()) {
      _permissionRefused = true;
      return;
    }

    final plan = planReminders(
      ReminderContext(
        now: now,
        routine: routine,
        streak: activity.streak,
        practicedToday: activity.practicedToday,
      ),
    );
    final l = _texts();
    await _service.cancelAll();
    for (final reminder in plan) {
      await _service.schedule(
        ScheduledNotification(
          id: reminder.id,
          at: reminder.at,
          title: l.reminderTitle,
          body: switch (reminder.kind) {
            ReminderKind.goal => l.reminderGoalBody,
            ReminderKind.streak => l.reminderStreakBody(
              l.homeStreakDays(reminder.streak),
            ),
          },
          payload: reminder.payload,
        ),
      );
    }
  }

  void dispose() {
    _disposed = true;
    _midnight?.cancel();
    if (_started) _lifecycle.dispose();
  }
}
