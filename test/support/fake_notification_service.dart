import 'package:parla_con_me/services/notifications/notification_service.dart';

/// A [NotificationService] that only remembers what it was asked: what is
/// scheduled now (by id, like the real one), how often everything was
/// cancelled, and how often the permission was asked for.
class FakeNotificationService implements NotificationService {
  FakeNotificationService({this.permission = true, this.launch});

  /// What [requestPermission] answers.
  bool permission;

  /// The payload of the notification that "opened the app", if any.
  String? launch;

  bool initialized = false;
  String? channelName;
  int permissionRequests = 0;
  int cancelAllCalls = 0;
  void Function(String? payload)? onSelected;

  final Map<int, ScheduledNotification> _scheduled = {};

  /// Everything scheduled right now, earliest first.
  List<ScheduledNotification> get scheduled =>
      _scheduled.values.toList()..sort((a, b) => a.at.compareTo(b.at));

  /// What is scheduled for the calendar day of [day].
  List<ScheduledNotification> on(DateTime day) => [
    for (final n in scheduled)
      if (n.at.year == day.year &&
          n.at.month == day.month &&
          n.at.day == day.day)
        n,
  ];

  /// The learner taps a notification while the app is running.
  void tap(String? payload) => onSelected?.call(payload);

  @override
  Future<void> initialize({
    required void Function(String? payload) onSelected,
    required String channelName,
    required String channelDescription,
  }) async {
    initialized = true;
    this.onSelected = onSelected;
    this.channelName = channelName;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<void> schedule(ScheduledNotification notification) async {
    _scheduled[notification.id] = notification;
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    _scheduled.clear();
  }

  @override
  Future<String?> launchPayload() async => launch;
}
