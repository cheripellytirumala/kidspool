/// Centralised, app-wide API constants.
///
/// The backend is the KidPool Supabase project. Every call goes to one of:
///   * `rest/v1/rpc/<name>`   — Postgres functions (PostgREST RPC)
///   * `functions/v1/<name>`  — Edge Functions (multipart uploads, OTP)
///   * `auth/v1/...`          — Supabase Auth (session refresh)
///   * `storage/v1/...`       — Storage (signed URLs for private photos)
///
/// Feature-specific function names live in each feature group's own
/// `core/constants` (e.g. `auth/core/constants/auth_api_constants.dart`).
abstract final class ApiConstants {
  // ---------------------------------------------------------------------------
  // Supabase project (per environment)
  // TODO: point staging/production at their own projects when they exist.
  // ---------------------------------------------------------------------------
  static const String devSupabaseUrl =
      'https://cojraqxramlirnepncrd.supabase.co/';
  static const String stagingSupabaseUrl = devSupabaseUrl;
  static const String productionSupabaseUrl = devSupabaseUrl;

  /// Publishable (client-safe) key. Never put the service-role key here.
  static const String devPublishableKey =
      'sb_publishable_fNCY2oyYmmvkCYKO8ZbAIg_7UJIhC0a';
  static const String stagingPublishableKey = devPublishableKey;
  static const String productionPublishableKey = devPublishableKey;

  // ---------------------------------------------------------------------------
  // Path prefixes
  // ---------------------------------------------------------------------------
  static const String rpcPrefix = 'rest/v1/rpc/';
  static const String functionsPrefix = 'functions/v1/';
  static const String storagePrefix = 'storage/v1';
  static const String refreshTokenPath = 'auth/v1/token';

  static String rpc(String name) => '$rpcPrefix$name';
  static String function(String name) => '$functionsPrefix$name';

  // ---------------------------------------------------------------------------
  // Timeouts
  // ---------------------------------------------------------------------------
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 60);

  // ---------------------------------------------------------------------------
  // Headers
  // ---------------------------------------------------------------------------
  static const String headerContentType = 'Content-Type';
  static const String headerAccept = 'Accept';
  static const String headerAuthorization = 'Authorization';
  static const String headerApiKey = 'apikey';
  static const String contentTypeJson = 'application/json';
  static const String bearerPrefix = 'Bearer';

  /// Set this key to `true` in `Options.extra` to skip token injection.
  static const String extraSkipAuth = 'skipAuth';

  /// Set internally on a request that was already retried after a refresh.
  static const String extraRetried = 'authRetried';

  // ---------------------------------------------------------------------------
  // Shared RPCs
  // ---------------------------------------------------------------------------
  /// `get_my_status()` → role, onboarding state, kids count, address flag.
  static const String getMyStatus = 'get_my_status';

  // ---------------------------------------------------------------------------
  // Common response keys
  // ---------------------------------------------------------------------------
  static const String kStatus = 'status';
  static const String kMessage = 'message';
  static const String kError = 'error';
  static const String kCode = 'code';
}
