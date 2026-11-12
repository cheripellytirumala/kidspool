import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../common/core/utils/logger.dart';
import '../../../ride_tracking/core/utils/ride_alert_payload.dart';
import '../../../ride_tracking/domain/entities/ride_alert.dart';
import '../constants/notifications_api_constants.dart';

/// Called when the user taps one of our system notifications.
typedef RideAlertTapCallback = void Function(RideAlertPayload payload);

/// S19 / S20 as system notifications posted by the app itself
/// (`flutter_local_notifications`) — works without any push setup.
abstract interface class LocalNotifications {
  /// Sets up the plugin (Android channel, iOS options) without asking for
  /// permission. [onTap] runs for taps while the app is alive.
  Future<void> init({required RideAlertTapCallback onTap});

  /// The notification whose tap launched the app, if any.
  Future<RideAlertPayload?> launchPayload();

  /// Shows the system prompt (iOS; Android 13+). True when allowed.
  Future<bool> requestPermission();

  /// Posts [alert] as a system notification (banner + Notification Center
  /// on iOS, also while the app is open).
  Future<void> showRideAlert(RideAlert alert);

  /// Ride Partner: a system notification at [at] ("You have a ride in
  /// 30 min…") for [requestId]; tapping it opens live tracking. Replaces
  /// any earlier one for the same ride.
  Future<void> scheduleRideReminder({
    required String requestId,
    required DateTime at,
    required String title,
    required String body,
  });

  Future<void> cancelRideReminder(String requestId);
}

class LocalNotificationsImpl implements LocalNotifications {
  LocalNotificationsImpl({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channel = AndroidNotificationChannel(
    NotificationsApiConstants.rideAlertsChannelId,
    NotificationsApiConstants.rideAlertsChannelName,
    description: NotificationsApiConstants.rideAlertsChannelDescription,
    importance: Importance.high,
  );

  @override
  Future<void> init({required RideAlertTapCallback onTap}) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is asked later, on Home (see RideNotifications).
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = RideAlertPayload.decode(response.payload);
        if (payload != null) onTap(payload);
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }

  @override
  Future<RideAlertPayload?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return RideAlertPayload.decode(details.notificationResponse?.payload);
  }

  @override
  Future<bool> requestPermission() async {
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
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  static int _reminderId(String requestId) =>
      RideAlertNotificationId.of('drive_reminder:$requestId');

  bool _tzReady = false;

  @override
  Future<void> scheduleRideReminder({
    required String requestId,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    try {
      if (!_tzReady) {
        tzdata.initializeTimeZones();
        _tzReady = true;
      }
      await _plugin.zonedSchedule(
        id: _reminderId(requestId),
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        title: title,
        body: body,
        payload: RideAlertPayload(
          kind: RideAlertKind.started,
          requestId: requestId,
        ).encode(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentBanner: true,
            presentList: true,
            presentSound: true,
          ),
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Could not schedule ride reminder',
        error: error,
        stackTrace: stackTrace,
        tag: 'Notifications',
      );
    }
  }

  @override
  Future<void> cancelRideReminder(String requestId) async {
    try {
      await _plugin.cancel(id: _reminderId(requestId));
    } catch (_) {
      // Nothing scheduled.
    }
  }

  @override
  Future<void> showRideAlert(RideAlert alert) async {
    final payload = RideAlertPayload.fromAlert(alert);
    final android = defaultTargetPlatform == TargetPlatform.android;
    try {
      await _plugin.show(
        // Same (tag, id) / identifier as the push for this event, so the two
        // replace each other (see RideAlertNotificationId).
        id: android ? 0 : RideAlertNotificationId.of(alert.id),
        title: alert.title,
        body: alert.body,
        payload: payload?.encode(),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            tag: alert.id,
          ),
          // Banner too while the app is open (simulators get no push, so
          // this is how the parent sees accepted / started / dropped off).
          iOS: const DarwinNotificationDetails(
            presentBanner: true,
            presentList: true,
            presentSound: true,
            presentBadge: false,
          ),
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Could not show ride alert',
        error: error,
        stackTrace: stackTrace,
        tag: 'Notifications',
      );
    }
  }
}
