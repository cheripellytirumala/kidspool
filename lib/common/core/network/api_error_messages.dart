/// User-facing text for the error codes returned by the KidPool Supabase
/// RPCs and Edge Functions.
abstract final class ApiErrorMessages {
  static const Map<String, String> _messages = {
    // OTP
    'invalid_phone': 'Enter a valid US mobile number.',
    'resend_too_soon': 'Please wait a moment before asking for a new code.',
    'sms_not_configured': 'We can’t send text messages right now. Try later.',
    'otp_failed': 'We couldn’t send the code. Please try again.',
    'invalid_otp_format': 'Enter the 6-digit code.',
    'otp_not_found': 'Ask for a new code first.',
    'otp_expired': 'This code has expired. Ask for a new one.',
    'invalid_otp': 'That code isn’t right. Please try again.',
    'too_many_attempts': 'Too many wrong codes. Ask for a new one.',
    'verify_failed': 'We couldn’t verify the code. Please try again.',
    'session_failed': 'We couldn’t sign you in. Please try again.',
    // Session / profile
    'not_authenticated': 'Your session has expired. Please sign in again.',
    'profile_not_found': 'We couldn’t find your profile. Please sign in again.',
    'invalid_role': 'Choose what you want to do on KidPool.',
    'role_required': 'Tell us what you want to do on KidPool first.',
    'not_a_parent': 'Only parent accounts can do this.',
    'not_approved': 'Your ID is still being reviewed. We’ll let you know soon.',
    // Identity
    'already_submitted': 'Your ID is already being reviewed.',
    'already_approved': 'Your ID is already verified.',
    'invalid_id_type': 'This type of ID isn’t accepted.',
    'submit_failed': 'We couldn’t send your ID. Please try again.',
    // Files
    'invalid_file_type': 'Photos must be JPEG or PNG.',
    'file_too_large': 'That photo is too large (max 1 MB).',
    'upload_failed': 'We couldn’t upload the photo. Please try again.',
    // Addresses
    'address_limit_reached': 'You can save up to 10 addresses.',
    'address_required': 'Add your home address first.',
    'address_not_found': 'That address no longer exists.',
    // Kids
    'kid_limit_reached': 'You can add up to 10 kids.',
    'kid_not_found': 'That child no longer exists.',
    'save_failed': 'We couldn’t save. Please try again.',
    'delete_failed': 'We couldn’t remove the child. Please try again.',
    'nothing_to_update': 'Nothing has changed.',
    // Rides
    'too_many_kids': 'A ride can take up to 4 kids.',
    'kids_different_schools': 'Pick kids who go to the same school.',
    'school_unavailable': 'Rides to this school aren’t available yet.',
    'pickup_too_soon': 'Pick-up must be at least 2 hours from now.',
    'duplicate_request': 'You already asked for a ride around that time.',
    // App version
    'invalid_platform': 'This device isn’t supported.',
    'invalid_version': 'This app version isn’t recognised.',
    'platform_not_configured': 'This device isn’t supported yet.',
  };

  static const Map<String, String> _fields = {
    'firstName': 'first name',
    'lastName': 'last name',
    'dateOfBirth': 'date of birth',
    'schoolId': 'school',
    'schoolIdCard': 'school ID card photo',
    'photo': 'photo',
    'selfie': 'profile photo',
    'idFront': 'front of your license',
    'idBack': 'back of your license',
    'idType': 'ID type',
    'grade': 'grade',
    'healthNotes': 'medical notes',
    'emergencyContactName': 'emergency contact name',
    'emergencyContactPhone': 'emergency contact phone',
  };

  /// Friendly text for [code]; `null` when the code is unknown.
  static String? forCode(String? code, {String? field, String? detail}) {
    if (code == null) return null;
    final label = _fields[field] ?? field;
    switch (code) {
      case 'missing_field':
        return label == null
            ? 'Please fill in all required fields.'
            : 'Please add the $label.';
      case 'invalid_field':
        if (label != null) return 'Please check the $label.';
        if (detail != null && detail.isNotEmpty) {
          return 'Please check: $detail.';
        }
        return 'Please check the details you entered.';
    }
    return _messages[code];
  }
}
