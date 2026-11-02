import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../error/exceptions.dart';

/// Single place that translates [DioException]s into [AppException]s.
abstract final class DioErrorMapper {
  static AppException map(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const NetworkException(
          'The connection timed out. Please try again.',
        );
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badCertificate:
        return const NetworkException(
          'Could not establish a secure connection.',
        );
      case DioExceptionType.cancel:
        return const NetworkException('The request was cancelled.');
      case DioExceptionType.badResponse:
        return _fromResponse(error.response);
      case DioExceptionType.unknown:
        if (error.error is AppException) return error.error! as AppException;
        if (error.error.toString().contains('SocketException')) {
          return const NetworkException();
        }
        return const ServerException();
    }
  }

  static AppException _fromResponse(Response<dynamic>? response) {
    final statusCode = response?.statusCode;
    final message = _extractMessage(response?.data);

    if (statusCode == 401) {
      return UnauthorizedException(message ?? 'Your session has expired.');
    }
    return ServerException(
      message ?? _defaultMessageFor(statusCode),
      statusCode,
    );
  }

  static String? _extractMessage(Object? data) {
    if (data is Map) {
      final message = data[ApiConstants.kMessage] ?? data['error'];
      if (message is String && message.trim().isNotEmpty) return message;
    }
    return null;
  }

  static String _defaultMessageFor(int? statusCode) => switch (statusCode) {
    400 => 'Bad request.',
    403 => 'You do not have permission to perform this action.',
    404 => 'The requested resource was not found.',
    422 => 'The submitted data is invalid.',
    int code when code >= 500 => 'Server error. Please try again later.',
    _ => 'Something went wrong. Please try again.',
  };
}
