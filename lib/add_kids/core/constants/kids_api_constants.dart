/// Supabase functions owned by the Kids feature group.
///
/// App-wide values (base URLs, headers, timeouts) stay in
/// `lib/core/constants/api_constants.dart`.
abstract final class KidsApiConstants {
  // RPCs
  /// `get_my_kids()` → `[{id, firstName, lastName, dateOfBirth, age, grade,
  /// school: {id, name}, needsBooster, healthNotes, emergencyContact,
  /// photoPath, schoolIdCardPath}]`.
  static const String getMyKids = 'get_my_kids';

  /// `school_from_place(placeId, name, addressLine, city, state, zip,
  /// latitude, longitude)` → `{id, name, addressLine, city, state, zip}`.
  /// Finds or creates the `schools` row for a Google place.
  static const String schoolFromPlace = 'school_from_place';

  /// `get_my_addresses()` → `[{id, label, addressLine1, ..., latitude,
  /// longitude, isDefault}]`; used to search "near home".
  static const String getMyAddresses = 'get_my_addresses';

  /// PostgREST code when an RPC isn't deployed (or the schema cache is
  /// stale).
  static const String functionNotFound = 'PGRST202';

  // Edge Functions
  /// multipart: firstName, dateOfBirth, schoolId, schoolIdCard (required);
  /// lastName, grade, needsBooster, healthNotes, photo (optional).
  static const String addKid = 'add-kid';

  /// multipart: kidId + only the fields to change.
  static const String updateKid = 'update-kid';

  /// Kids' activities on the server
  /// (`docs/backend/2026-11-11_kid_activities.sql`).
  static const String setMyKidActivities = 'set_my_kid_activities';
  static const String getMyKidActivities = 'get_my_kid_activities';

  /// Schools KidPool already knows (`get_schools(search)`), searched before
  /// Google so the small Google quota isn't needed.
  static const String getSchools = 'get_schools';

  /// Activity places parents already saved
  /// (`docs/backend/2026-11-12_search_activity_places.sql`).
  static const String searchActivityPlaces = 'search_activity_places';

  /// JSON: `{kidId}`.
  static const String deleteKid = 'delete-kid';

  // Storage
  /// Private bucket: `<parentId>/<kidId>.jpg`, `<parentId>/<kidId>_school_id.jpg`.
  static const String kidPhotosBucket = 'kid-photos';

  /// Lifetime of signed photo URLs.
  static const int signedUrlSeconds = 3600;
}
