/// Supabase function and local keys owned by the Notifications feature.
abstract final class NotificationsApiConstants {
  /// `get_my_notifications()` → newest first, `[{id, kind, title, body,
  /// createdAt, requestId, iAmDriver, otherId, otherName, otherInitials}]`.
  /// SQL: docs/backend/2026-11-05_get_my_notifications.sql.
  static const String getMyNotifications = 'get_my_notifications';

  /// PostgREST code when the RPC isn't deployed yet.
  static const String functionNotFound = 'PGRST202';

  /// SharedPreferences key: newest notification time the user has seen.
  /// Shared with the Home bell dot.
  static const String seenAtKey = 'home.notifications_seen_at';
}
