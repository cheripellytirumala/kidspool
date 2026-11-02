import 'package:dio/dio.dart';

import '../config/environment.dart';
import '../constants/api_constants.dart';
import 'auth_token_provider.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

/// Builds the app's configured [Dio] instance.
abstract final class DioClient {
  static Dio create({
    required EnvConfig config,
    required AuthTokenProvider tokenProvider,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.configBaseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        sendTimeout: ApiConstants.sendTimeout,
        responseType: ResponseType.json,
        headers: const {
          ApiConstants.headerContentType: ApiConstants.contentTypeJson,
          ApiConstants.headerAccept: ApiConstants.contentTypeJson,
        },
      ),
    );

    // Order matters: auth → logging (sees final headers) → error mapping.
    dio.interceptors.addAll([
      AuthInterceptor(tokenProvider),
      if (config.enableLogging) LoggingInterceptor(),
      ErrorInterceptor(),
    ]);

    return dio;
  }
}
