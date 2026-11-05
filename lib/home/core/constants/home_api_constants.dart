import '../../../notifications/core/constants/notifications_api_constants.dart';

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

  /// `get_families_near_me(schoolId?, radiusMiles = 10)` → `[{id, firstName,
  /// lastInitial, initials, givesRides, kids: [{firstName, schoolId,
  /// schoolName}], distanceMiles}]`, nearest first.
  static const String getFamiliesNearMe = 'get_families_near_me';

  /// `get_my_kids()` → `[{id, firstName, school: {id, name}, …}]`; used only
  /// to tell "no kids with a school yet" from "no families found".
  static const String getMyKids = 'get_my_kids';

  /// Default search radius of [getFamiliesNearMe] (the server clamps 1–25).
  static const double familiesRadiusMiles = 10;

  /// PostgREST code when an RPC isn't deployed (or the schema cache is
  /// stale).
  static const String functionNotFound = 'PGRST202';

  /// `Failure.code` set when [getFamiliesNearMe] isn't on the server yet.
  static const String familiesNearMeMissing = 'families_near_me_missing';

  static const String scopeUpcoming = 'upcoming';

  /// SharedPreferences key: newest notification time the user has seen.
  /// Same key as the Notifications screen, which marks rows seen.
  static const String notificationsSeenAtKey =
      NotificationsApiConstants.seenAtKey;
}
