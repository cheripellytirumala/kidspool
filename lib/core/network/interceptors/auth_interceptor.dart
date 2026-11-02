import 'package:dio/dio.dart';

import '../../constants/api_constants.dart';
import '../auth_token_provider.dart';

/// Injects `Authorization: Bearer <token>` when a token is available.
///
/// Opt out per request with `Options(extra: {ApiConstants.extraSkipAuth: true})`.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor(this._tokenProvider);

  final AuthTokenProvider _tokenProvider;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final skipAuth = options.extra[ApiConstants.extraSkipAuth] == true;
    if (!skipAuth) {
      final token = await _tokenProvider.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers[ApiConstants.headerAuthorization] =
            '${ApiConstants.bearerPrefix} $token';
      }
    }
    handler.next(options);
  }
}
