import 'package:dio/dio.dart';

import '../dio_error_mapper.dart';

/// Attaches a typed [AppException] to every failed request, so callers only
/// ever deal with the app's own exception hierarchy.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err.copyWith(error: DioErrorMapper.map(err)));
  }
}
