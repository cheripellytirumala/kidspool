/// App-wide, non-network constants.
abstract final class AppConstants {
  static const String appName = 'KidsPool';

  /// Role sent to the backend for this app build.
  static const int roleId = 1;

  /// Version number reported to `getAppVersion`.
  static const String appVersionNumber = '2.0';

  static const String deviceIos = 'ios';
  static const String deviceAndroid = 'android';

  // Local cache keys
  static const String cacheKeyAppVersion = 'cache_app_version';
}
