/// Supabase functions owned by the AskRide feature group.
///
/// App-wide values (base URLs, headers, timeouts) stay in
/// `lib/core/constants/api_constants.dart`.
abstract final class AskRideApiConstants {
  /// `get_my_addresses()` → `[{id, label, addressLine1, ..., isDefault}]`.
  static const String getMyAddresses = 'get_my_addresses';

  /// `add_address(addressLine1, addressLine2, city, state, zip, latitude,
  /// longitude, label, isDefault)` — saves an address picked on the map.
  static const String addAddress = 'add_address';

  /// `create_ride_request(kidIds, pickupDate, pickupTime, timeZone,
  /// pickupAddressId, pickupAddress, note, repeatSchoolDays, requireApproval,
  /// dropoffAddress)` → `{seriesId, eligibleDriversCount, requests}`. Rides
  /// go from the pickup address to the kids' school, or to `dropoffAddress`
  /// (`{label, addressLine1, city, state, zip, latitude, longitude}`) when
  /// set — that argument needs
  /// `docs/backend/2026-11-03_ride_dropoff_location.sql`.
  static const String createRideRequest = 'create_ride_request';

  /// `get_schools(search)` → `[{id, name, addressLine, city, state, zip,
  /// latitude, longitude}]`; used for the school's location on a ride home.
  static const String getSchools = 'get_schools';
  static const String schoolLocationMissingMessage =
      'We couldn’t find where this school is. Try again later.';

  /// PostgREST "function not found" (e.g. `dropoffAddress` before the SQL).
  static const String functionNotFound = 'PGRST202';

  /// Client-side code for a custom drop-off the server doesn't know yet.
  static const String dropoffNotSupported = 'dropoff_not_supported';
  static const String dropoffNotSupportedMessage =
      "Rides home and drop-offs at any place aren't set up on the server "
      "yet. Ask for a ride to your kid's school for now.";

  /// `create_ride_request`: the drop-off is within 50 m of the pick-up.
  static const String samePlace = 'same_place';
  static const String samePlaceMessage =
      'Pick-up and drop-off can’t be the same place.';

  /// Two places closer than this count as the same (matches the server).
  static const double samePlaceMeters = 50;

  /// Max length of `ride_requests.note`.
  static const int maxNoteLength = 300;
}
