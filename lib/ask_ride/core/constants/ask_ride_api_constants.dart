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
  /// pickupAddressId, pickupAddress, note, repeatSchoolDays, requireApproval)`
  /// → `{seriesId, eligibleDriversCount, requests}`. Rides always go from
  /// the pickup address to the kids' school.
  static const String createRideRequest = 'create_ride_request';

  /// Max length of `ride_requests.note`.
  static const int maxNoteLength = 300;
}
