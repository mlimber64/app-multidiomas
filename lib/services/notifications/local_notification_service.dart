import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_service.dart';

/// [NotificationService] on `flutter_local_notifications`, for Android and iOS.
///
/// Notifications are one-shot and scheduled with an inexact alarm that still
/// fires in Doze: a practice reminder does not need to land at the exact
/// second, and exact alarms need a special permission that the stores only
/// allow for alarm and calendar apps. They may arrive a few minutes late.
/// Every call is safe on a platform without the plugin: it fails quietly.
class LocalNotificationService implements NotificationService {
  LocalNotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Channel the reminders are posted on.
  static const channelId = 'daily_reminders';

  String _channelName = 'Practice reminders';
  String _channelDescription = 'Daily practice reminders.';
  bool _ready = false;

  @override
  Future<void> initialize({
    required void Function(String? payload) onSelected,
    required String channelName,
    required String channelDescription,
  }) async {
    _channelName = channelName;
    _channelDescription = channelDescription;
    try {
      // Time zones: with the device's own, a time of day means the same
      // wall-clock time wherever the learner is.
      tz_data.initializeTimeZones();
      try {
        final zone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zone.identifier));
      } catch (_) {
        // Without the zone, tz.local stays UTC. A one-shot notification is
        // an instant, so it still goes out at the right moment.
      }
      _ready =
          await _plugin.initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('ic_notification'),
              // The permission is asked for when it is needed (see
              // requestPermission), not when the app opens.
              iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false,
              ),
            ),
            onDidReceiveNotificationResponse: (response) =>
                onSelected(response.payload),
          ) ??
          false;
    } catch (_) {
      _ready = false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        if (await android.areNotificationsEnabled() ?? false) return true;
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  @override
  Future<void> schedule(ScheduledNotification notification) async {
    if (!_ready) return;
    try {
      await _plugin.zonedSchedule(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        payload: notification.payload,
        scheduledDate: tz.TZDateTime.from(notification.at, tz.local),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            _channelName,
            channelDescription: _channelDescription,
            icon: 'ic_notification',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      // A reminder that cannot be scheduled is not worth an error on screen.
      if (kDebugMode) debugPrint('Could not schedule a reminder: $e');
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  @override
  Future<String?> launchPayload() async {
    if (!_ready) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        return details?.notificationResponse?.payload;
      }
    } catch (_) {}
    return null;
  }
}
