import 'dart:convert';

import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../error/exceptions.dart';
import 'api_error_messages.dart';

/// Single place that translates [DioException]s into [AppException]s.
///
/// Understands both Supabase error shapes:
///   * PostgREST / RPC: `{code: "PT409", message: "role_already_set", details}`
///   * Edge Functions:  `{error: "resend_too_soon", retryAfter: 12, field}`
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

  static final RegExp _snakeCode = RegExp(r'^[a-z][a-z0-9_]*$');

  static AppException _fromResponse(Response<dynamic>? response) {
    final statusCode = response?.statusCode;
    final body = _bodyOf(response?.data);

    // Edge Functions put the code in `error`; RPCs in `message`.
    final edgeCode = body[ApiConstants.kError];
    final rpcMessage = body[ApiConstants.kMessage];
    final String? code = edgeCode is String
        ? edgeCode
        : (rpcMessage is String && _snakeCode.hasMatch(rpcMessage))
        ? rpcMessage
        : null;

    final field = body['field'] is String ? body['field'] as String : null;
    final details = body['details'] is String
        ? body['details'] as String
        : null;
    final message =
        ApiErrorMessages.forCode(code, field: field, detail: details) ??
        _readableMessage(body) ??
        _defaultMessageFor(statusCode);

    if (statusCode == 401) return UnauthorizedException(message, code);
    return ServerException(message, statusCode, code, body);
  }

  static Map<String, dynamic> _bodyOf(Object? data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.trim().startsWith('{')) {
      try {
        return Map<String, dynamic>.from(jsonDecode(data) as Map);
      } catch (_) {}
    }
    return const {};
  }

  /// A server message that is already human-readable (Auth errors, etc.).
  static String? _readableMessage(Map<String, dynamic> body) {
    for (final key in const [
      'msg',
      'error_description',
      ApiConstants.kMessage,
    ]) {
      final value = body[key];
      if (value is String &&
          value.trim().isNotEmpty &&
          !_snakeCode.hasMatch(value)) {
        return value;
      }
    }
    return null;
  }

  static String _defaultMessageFor(int? statusCode) => switch (statusCode) {
    400 => 'Please check the details you entered.',
    403 => 'You do not have permission to perform this action.',
    404 => 'The requested resource was not found.',
    409 => 'That conflicts with something you already did.',
    413 => 'That photo is too large (max 1 MB).',
    422 => 'The submitted data is invalid.',
    429 => 'Too many attempts. Please wait a moment.',
    int code when code >= 500 => 'Server error. Please try again later.',
    _ => 'Something went wrong. Please try again.',
  };
}
