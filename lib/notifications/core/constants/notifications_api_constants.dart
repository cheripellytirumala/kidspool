/// Supabase function and local keys owned by the Notifications feature.
abstract final class NotificationsApiConstants {
  /// `get_my_notifications()` → newest first, `[{id, kind, title, body,
  /// createdAt, requestId, iAmDriver, otherId, otherName, otherInitials}]`.
  /// SQL: docs/backend/2026-11-05_get_my_notifications.sql.
  static const String getMyNotifications = 'get_my_notifications';

  /// PostgREST code when the RPC isn't deployed yet.
  static const String functionNotFound = 'PGRST202';

  /// `register_push_token(token, platform)` — stores this device's FCM
  /// token for the signed-in user (`platform`: [platformIos] /
  /// [platformAndroid]). SQL: docs/backend/2026-11-10_push_tokens.sql.
  static const String registerPushToken = 'register_push_token';

  /// `unregister_push_token(token)` — forgets this device's FCM token
  /// (sign-out). Only deletes the caller's own row.
  static const String unregisterPushToken = 'unregister_push_token';

  static const String platformIos = 'ios';
  static const String platformAndroid = 'android';

  /// SharedPreferences key: notification permission was already asked on
  /// this device (asked once, on Home).
  static const String permissionAskedKey = 'notifications.permission_asked';

  /// Android channel for S19 / S20 (local notifications and pushes; the
  /// `send-ride-push` Edge Function sends this `channel_id`).
  static const String rideAlertsChannelId = 'ride_alerts';
  static const String rideAlertsChannelName = 'Ride alerts';
  static const String rideAlertsChannelDescription =
      'Ride started and arrived at school';

  /// SharedPreferences key: newest notification time the user has seen.
  /// Shared with the Home bell dot.
  static const String seenAtKey = 'home.notifications_seen_at';
}
