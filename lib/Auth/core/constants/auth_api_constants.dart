/// Supabase functions owned by the Auth feature group.
///
/// App-wide values (base URLs, headers, timeouts) stay in
/// `lib/core/constants/api_constants.dart`.
abstract final class AuthApiConstants {
  // Edge Functions
  /// `{phone}` → `{status, expiresIn, resendAfter, otp?}` (otp in demo mode).
  static const String requestOtp = 'request-otp';

  /// `{phone, otp}` → `{status, isNewUser, role, onboardingStatus, user, session}`.
  static const String verifyOtp = 'verify-otp';

  /// multipart: firstName, lastName, idType, selfie, idFront, idBack.
  static const String submitIdentityVerification =
      'submit-identity-verification';

  // RPCs
  /// `set_my_role(role)` — `parent` or `staff`, only while empty.
  static const String setMyRole = 'set_my_role';

  /// `set_my_profile_basics(firstName, lastName, startNow)`: saves the name;
  /// with startNow ("I need rides") approves the parent at once
  /// (`docs/backend/2026-11-11_no_id_review_for_riders.sql`).
  static const String setMyProfileBasics = 'set_my_profile_basics';

  /// `add_address(addressLine1, city, state, zip, latitude, longitude,
  /// label, addressLine2, isDefault)`.
  static const String addAddress = 'add_address';

  // Values
  static const String roleParent = 'parent';

  /// `id_document_types.code` scanned on V1 ("Scan your driver's license").
  static const String idTypeDriversLicense = 'drivers_license';

  /// US numbers only in the app (the backend also accepts +91).
  static const String countryCode = '+1';
}
