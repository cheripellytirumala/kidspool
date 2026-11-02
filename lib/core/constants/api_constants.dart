/// Centralised, app-wide API constants.
///
/// Feature-specific endpoints live in each feature group's own
/// `core/constants` (e.g. `Auth/core/constants/auth_api_constants.dart`).
abstract final class ApiConstants {
  // ---------------------------------------------------------------------------
  // Base URLs (per environment)
  // TODO: replace staging/production with their real hosts when available.
  // ---------------------------------------------------------------------------
  static const String devConfigBaseUrl = 'https://admin.ebounti.com/api/';
  static const String stagingConfigBaseUrl = 'https://admin.ebounti.com/api/';
  static const String productionConfigBaseUrl =
      'https://admin.ebounti.com/api/';

  // ---------------------------------------------------------------------------
  // Timeouts
  // ---------------------------------------------------------------------------
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // ---------------------------------------------------------------------------
  // Headers
  // ---------------------------------------------------------------------------
  static const String headerContentType = 'Content-Type';
  static const String headerAccept = 'Accept';
  static const String headerAuthorization = 'Authorization';
  static const String contentTypeJson = 'application/json';
  static const String bearerPrefix = 'Bearer';

  /// Set this key to `true` in `Options.extra` to skip token injection.
  static const String extraSkipAuth = 'skipAuth';

  // ---------------------------------------------------------------------------
  // Endpoints
  // ---------------------------------------------------------------------------
  static const String getAppVersion = 'getAppVersion';

  // ---------------------------------------------------------------------------
  // Query parameter keys
  // ---------------------------------------------------------------------------
  static const String qRoleId = 'role_id';
  static const String qDevice = 'device';
  static const String qVersionNumber = 'version_number';

  // ---------------------------------------------------------------------------
  // Common response keys
  // ---------------------------------------------------------------------------
  static const String kStatus = 'status';
  static const String kMessage = 'message';

  /// Value of [kStatus] that marks a successful business response.
  static const int statusSuccess = 1;
}
