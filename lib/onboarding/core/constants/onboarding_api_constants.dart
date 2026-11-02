/// Endpoints and keys owned by the Onboarding group (launch / app version).
///
/// App-wide values (base URLs, headers, timeouts) stay in
/// `lib/common/core/constants/api_constants.dart`.
abstract final class OnboardingApiConstants {
  /// `check_app_version(platform, appVersion)` → `{status, ...}`.
  static const String checkAppVersion = 'check_app_version';

  /// Local cache key for the last app-version response.
  static const String cacheKeyAppVersion = 'cache_app_version';
}
