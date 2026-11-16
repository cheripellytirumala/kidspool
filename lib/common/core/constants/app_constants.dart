/// App-wide, non-network constants.
abstract final class AppConstants {
  static const String appName = 'KidsPool';

  /// Version reported to `check_app_version` (must look like `1.2.3`).
  static const String appVersionNumber = appDisplayVersion;

  /// Version shown on the splash screen.
  static const String appDisplayVersion = '1.0.1';

  static const String deviceIos = 'ios';
  static const String deviceAndroid = 'android';

  /// "I need rides" / "I can offer and request rides" picked on About you.
  static const String cacheKeyRideRole = 'ride_role';

  /// Opened in-app from "I agree to the Terms and Privacy Policy".
  static const String termsUrl =
      'https://nfcsolutionsindia.github.io/kidpool-web/terms';
  static const String privacyUrl =
      'https://kidspool-legal.netlify.app/privacy/';

  /// Profile › Help & support: KidPool website (FAQ, safety, contact).
  static const String supportUrl =
      'https://nfcsolutionsindia.github.io/kidpool-web/';
}
