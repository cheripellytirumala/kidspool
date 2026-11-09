/// App-wide, non-network constants.
abstract final class AppConstants {
  static const String appName = 'kidpool';

  /// Version reported to `check_app_version` (must look like `1.2.3`).
  static const String appVersionNumber = appDisplayVersion;

  /// Version shown on the splash screen.
  static const String appDisplayVersion = '1.0.1';

  static const String deviceIos = 'ios';
  static const String deviceAndroid = 'android';

  /// "I need rides" / "I can offer and request rides" picked on About you.
  static const String cacheKeyRideRole = 'ride_role';

  // TODO: replace with the real pages before release (placeholders).
  /// Opened in-app from "I agree to the Terms and Privacy Policy".
  static const String termsUrl = 'https://example.com/terms';
  static const String privacyUrl = 'https://example.com/privacy';

  /// Profile › Help & support (placeholder, like the two above).
  static const String supportUrl = 'https://example.com/help';
}
