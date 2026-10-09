/// One local notification to show at a given moment.
class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
  });

  /// Stable id: scheduling the same id again replaces the earlier one.
  final int id;

  /// Local date and time it goes out.
  final DateTime at;
  final String title;
  final String body;

  /// Comes back to [NotificationService.initialize]'s callback when tapped.
  final String payload;
}

/// What the app can ask of the platform's local notifications. Nothing here
/// knows about reminders: that is `ReminderScheduler`'s business. Provider
/// neutral (a fake stands in for it in tests). Implementations never throw: a
/// platform that cannot do something just does nothing.
abstract interface class NotificationService {
  /// Prepares the notifications. [onSelected] gets the payload of a
  /// notification the learner taps while the app is running. The channel name
  /// and description are what the system settings show for the app's
  /// notifications.
  Future<void> initialize({
    required void Function(String? payload) onSelected,
    required String channelName,
    required String channelDescription,
  });

  /// Asks for permission to show notifications (once, at the moment it is
  /// needed) and says whether there is one. Asking again after a refusal does
  /// not bother the learner: the system decides whether to show the question.
  Future<bool> requestPermission();

  /// Schedules [notification] (replacing one with the same id).
  Future<void> schedule(ScheduledNotification notification);

  /// Removes every notification this app has scheduled.
  Future<void> cancelAll();

  /// The payload of the notification that opened the app from closed, if that
  /// is how it was opened.
  Future<String?> launchPayload();
}
