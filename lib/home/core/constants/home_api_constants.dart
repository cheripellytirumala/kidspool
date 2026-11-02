/// Supabase functions owned by the Home feature group.
///
/// App-wide values (base URLs, headers, timeouts) stay in
/// `lib/core/constants/api_constants.dart`.
abstract final class HomeApiConstants {
  /// `get_my_ride_requests(scope)` — `upcoming` (open/confirmed/in progress)
  /// or `past`.
  static const String getMyRideRequests = 'get_my_ride_requests';

  /// `get_my_drives(scope)` — `upcoming` returns `{drives, pendingOffers}`.
  static const String getMyDrives = 'get_my_drives';

  /// `get_request_activity(requestId)` — `{notifiedCount, driver, …}`.
  static const String getRequestActivity = 'get_request_activity';

  /// `get_my_notifications()` — newest first, `[{id, kind, title, createdAt}]`.
  static const String getMyNotifications = 'get_my_notifications';

  static const String scopeUpcoming = 'upcoming';

  /// SharedPreferences key: newest notification time the user has seen.
  static const String notificationsSeenAtKey = 'home.notifications_seen_at';
}
