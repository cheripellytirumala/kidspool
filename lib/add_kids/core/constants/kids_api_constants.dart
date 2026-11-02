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

  /// `get_schools(search)` → `[{id, name, addressLine, city, state, zip,
  /// latitude, longitude}]` (max 50).
  static const String getSchools = 'get_schools';

  // Edge Functions
  /// multipart: firstName, dateOfBirth, schoolId, schoolIdCard (required);
  /// lastName, grade, needsBooster, healthNotes, photo (optional).
  static const String addKid = 'add-kid';

  /// multipart: kidId + only the fields to change.
  static const String updateKid = 'update-kid';

  /// JSON: `{kidId}`.
  static const String deleteKid = 'delete-kid';

  // Storage
  /// Private bucket: `<parentId>/<kidId>.jpg`, `<parentId>/<kidId>_school_id.jpg`.
  static const String kidPhotosBucket = 'kid-photos';

  /// Lifetime of signed photo URLs.
  static const int signedUrlSeconds = 3600;
}
