import 'package:dio/dio.dart';

import '../../constants/api_constants.dart';
import '../../utils/logger.dart';

/// Logs requests, responses and errors. Only added to Dio in non-production
/// environments; also no-ops if [AppLogger] is disabled.
class LoggingInterceptor extends Interceptor {
  static const _tag = 'HTTP';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.debug(
      '--> ${options.method} ${options.uri}\n'
      'Headers: ${_redact(options.headers)}\n'
      'Body: ${options.data}',
      tag: _tag,
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    AppLogger.info(
      '<-- ${response.statusCode} ${response.requestOptions.method} '
      '${response.requestOptions.uri}\n'
      'Response: ${response.data}',
      tag: _tag,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.error(
      '<-- ${err.response?.statusCode ?? 'ERR'} ${err.requestOptions.method} '
      '${err.requestOptions.uri}\n'
      'Type: ${err.type.name} | Message: ${err.message}\n'
      'Response: ${err.response?.data}',
      error: err.error,
      tag: _tag,
    );
    handler.next(err);
  }

  Map<String, dynamic> _redact(Map<String, dynamic> headers) => {
    for (final entry in headers.entries)
      entry.key: entry.key == ApiConstants.headerAuthorization
          ? '***'
          : entry.value,
  };
}
