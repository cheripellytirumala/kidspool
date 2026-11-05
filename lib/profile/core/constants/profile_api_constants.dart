/// Supabase endpoints owned by the Profile feature group.
///
/// App-wide values (base URLs, headers, `get_my_status`) stay in
/// `lib/common/core/constants/api_constants.dart`.
abstract final class ProfileApiConstants {
  // Tables (PostgREST)
  /// `profiles` row of the signed-in user (RLS: own row only).
  static const String profilesTable = 'rest/v1/profiles';

  /// Columns read for the profile header.
  static const String profileColumns = 'first_name,last_name,full_name,phone';

  // RPCs
  /// `get_my_addresses()` → `[{id, label, addressLine1, addressLine2, city,
  /// state, zip, latitude, longitude, isDefault}]` (default first).
  static const String getMyAddresses = 'get_my_addresses';

  /// `add_address(addressLine1, addressLine2, city, state, zip, latitude,
  /// longitude, label, isDefault)` — the first address is always default.
  static const String addAddress = 'add_address';

  /// `set_default_address(addressId)`.
  static const String setDefaultAddress = 'set_default_address';

  /// `delete_address(addressId)` — deleting the default promotes the newest
  /// remaining address.
  static const String deleteAddress = 'delete_address';

  // Params
  static const String pAddressId = 'addressId';
}
