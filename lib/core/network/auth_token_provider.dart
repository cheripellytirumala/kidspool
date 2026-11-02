/// Source of the access token injected by [AuthInterceptor].
///
/// The Auth feature group owns the real implementation (backed by secure
/// storage) and re-registers it in DI; [InMemoryAuthTokenProvider] is the
/// default so the network layer works before Auth is wired.
abstract interface class AuthTokenProvider {
  Future<String?> getAccessToken();

  Future<void> saveAccessToken(String token);

  Future<void> clear();
}

class InMemoryAuthTokenProvider implements AuthTokenProvider {
  String? _token;

  @override
  Future<String?> getAccessToken() async => _token;

  @override
  Future<void> saveAccessToken(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
