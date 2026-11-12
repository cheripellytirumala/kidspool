/// Supabase RPCs owned by the RideTracking feature group (ride day).
///
/// Ported from the previous KidPool app; same backend, same contracts.
/// App-wide values (base URLs, headers, timeouts) stay in
/// `lib/common/core/constants/api_constants.dart`.
abstract final class RideTrackingApiConstants {
  /// `get_ride_tracking(requestId, includePath)` → `{myRole, requestId,
  /// status, pickupAt, estimatedDropoffAt, startedAt, pickedUpAt,
  /// completedAt, school{name, latitude, longitude}, pickupAddress{label,
  /// addressLine1, latitude, longitude}, currentLocation{latitude, longitude,
  /// heading, speed, at}, distanceMiles, plannedTripMiles, rideMinutes,
  /// kids[{id, firstName, lastName, photoPath}], driver{id, firstName,
  /// lastName, initials, phone, vehicle{model, plateNumber}}, parent{id,
  /// firstName, lastName, initials, phone}, openSos, rating, path[[lat, lng]]}`.
  static const String getRideTracking = 'get_ride_tracking';

  /// Ride Partner: `start_ride(requestId, latitude?, longitude?)` — allowed
  /// any time while confirmed (the 30-min window is off for now).
  static const String startRide = 'start_ride';

  /// Ride Partner: `update_ride_location(requestId, latitude, longitude,
  /// heading?, speed?, accuracy?)` → `{distanceMiles}`.
  static const String updateRideLocation = 'update_ride_location';

  /// Ride Partner: `mark_picked_up(requestId, latitude?, longitude?)`.
  static const String markPickedUp = 'mark_picked_up';

  /// Ride Partner: `complete_ride(requestId, latitude?, longitude?)` →
  /// `{completedAt, distanceMiles, rideMinutes, distanceFromSchoolMeters}`.
  static const String completeRide = 'complete_ride';

  /// Parent or Ride Partner: `trigger_sos(requestId, latitude?, longitude?,
  /// note?)` → the open SOS event.
  static const String triggerSos = 'trigger_sos';

  /// Requesting parent: `rate_ride(requestId, rating 1–5, thankYou, comment?)`
  /// — once per completed ride.
  static const String rateRide = 'rate_ride';

  /// `get_my_notifications()` → `[{id, kind, title, body, data, readAt,
  /// createdAt}]`, newest first (max 100).
  static const String getMyNotifications = 'get_my_notifications';

  /// Private bucket for kid photos (`kids[].photoPath`).
  static const String kidPhotosBucket = 'kid-photos';

  /// Lifetime of signed kid photo URLs.
  static const int signedUrlSeconds = 3600;

  // ------------------------------------------------------------ cadences

  /// How often the live screen re-reads `get_ride_tracking` while visible
  /// (replaces the old app's Realtime channel).
  static const Duration trackingPollInterval = Duration(seconds: 10);

  /// The Ride Partner's position goes out every this often while the ride
  /// is in progress (also when the car hasn't moved, so the parent's map
  /// stays current).
  static const Duration locationInterval = Duration(seconds: 10);

  /// Minimum movement between GPS fixes from the position stream.
  static const int locationDistanceFilterMeters = 10;

  /// How often [RideAlertsHost] reads `get_my_notifications` while the app
  /// is in the foreground.
  static const Duration alertsPollInterval = Duration(seconds: 30);

  /// Ride alerts older than this are not shown as banners.
  static const Duration alertFreshness = Duration(minutes: 3);

  /// The Ride Partner can drop off (button) — and the ride drops off by
  /// itself — once the car is within this distance of the drop-off.
  static const double dropoffRadiusMeters = 100;

  /// The drop-off counts as "within 100 ft" of the school (geofence radius).
  static const double schoolZoneMeters = 30.48;
}
