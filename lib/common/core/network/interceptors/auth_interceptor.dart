import 'package:dio/dio.dart';

import '../../constants/api_constants.dart';
import '../../utils/logger.dart';
import '../auth_token_provider.dart';

/// Injects `Authorization: Bearer <access token>` and keeps the Supabase
/// session fresh:
///   * refreshes the token shortly before it expires;
///   * on a 401, refreshes once and replays the request.
///
/// Opt out per request with `Options(extra: {ApiConstants.extraSkipAuth: true})`.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required AuthTokenProvider tokenProvider,
    required Dio dio,
    required String supabaseUrl,
    required String publishableKey,
    Dio? refreshDio,
  }) : _tokenProvider = tokenProvider,
       _dio = dio,
       _refreshDio =
           refreshDio ??
           Dio(
             BaseOptions(
               baseUrl: supabaseUrl,
               connectTimeout: ApiConstants.connectTimeout,
               receiveTimeout: ApiConstants.receiveTimeout,
               headers: {
                 ApiConstants.headerApiKey: publishableKey,
                 ApiConstants.headerContentType: ApiConstants.contentTypeJson,
               },
             ),
           );

  final AuthTokenProvider _tokenProvider;

  /// The main client, used to replay a request after a refresh.
  final Dio _dio;

  /// Bare client for the refresh call (no interceptors → no recursion).
  final Dio _refreshDio;

  static const _tag = 'Auth';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[ApiConstants.extraSkipAuth] != true) {
      var session = _tokenProvider.session;
      if (session != null && session.isExpiring()) {
        session = await _refresh(session);
      }
      if (session != null) {
        options.headers[ApiConstants.headerAuthorization] =
            '${ApiConstants.bearerPrefix} ${session.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final session = _tokenProvider.session;
    final canRetry =
        err.response?.statusCode == 401 &&
        session != null &&
        options.extra[ApiConstants.extraSkipAuth] != true &&
        options.extra[ApiConstants.extraRetried] != true;
    if (!canRetry) return handler.next(err);

    // Several requests often fail together (the app was in the background
    // and the token expired). Only the first refreshes; the rest replay
    // with the session it saved, instead of each refreshing again (that
    // burst got rate-limited by Supabase, 429, and every screen failed).
    final sent = options.headers[ApiConstants.headerAuthorization];
    final current = '${ApiConstants.bearerPrefix} ${session.accessToken}';
    final refreshed = sent != current && !session.isExpiring()
        ? session
        : await _refresh(session);
    if (refreshed == null) return handler.next(err);

    try {
      options
        ..extra[ApiConstants.extraRetried] = true
        ..headers[ApiConstants.headerAuthorization] =
            '${ApiConstants.bearerPrefix} ${refreshed.accessToken}';
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// The refresh in flight, shared by everyone who needs one meanwhile.
  Future<AuthSession?>? _refreshing;

  /// When the last refresh was rate-limited (429): don't retry before.
  DateTime? _retryRefreshAfter;

  /// Exchanges the refresh token for a new session, once for all callers
  /// waiting at the same time.
  Future<AuthSession?> _refresh(AuthSession current) {
    final wait = _retryRefreshAfter;
    if (wait != null && DateTime.now().isBefore(wait)) {
      return Future.value(null);
    }
    return _refreshing ??= _doRefresh(
      current,
    ).whenComplete(() => _refreshing = null);
  }

  /// Clears the stored session when the refresh token is no longer valid.
  Future<AuthSession?> _doRefresh(AuthSession current) async {
    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        ApiConstants.refreshTokenPath,
        queryParameters: const {'grant_type': 'refresh_token'},
        data: {'refresh_token': current.refreshToken},
      );
      final data = response.data ?? const {};
      final access = data['access_token'];
      final refresh = data['refresh_token'];
      if (access is! String || refresh is! String) return null;
      final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
      final expiresAt =
          (data['expires_at'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + expiresIn;
      final user = data['user'];
      final session = AuthSession(
        accessToken: access,
        refreshToken: refresh,
        expiresAt: expiresAt,
        userId: user is Map ? user['id'] as String? : current.userId,
      );
      await _tokenProvider.saveSession(session);
      return session;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      AppLogger.warning('Session refresh failed ($code)', tag: _tag);
      if (code == 429) {
        _retryRefreshAfter = DateTime.now().add(const Duration(seconds: 15));
      }
      if (code == 400 || code == 401 || code == 403) {
        await _tokenProvider.clear();
      }
      return null;
    }
  }
}
