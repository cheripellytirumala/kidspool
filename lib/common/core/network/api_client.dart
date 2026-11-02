import 'dart:convert';

import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../error/exceptions.dart';
import '../utils/logger.dart';
import 'dio_error_mapper.dart';

/// Converts a decoded response body into a typed value.
typedef ResponseParser<T> = T Function(dynamic json);

/// Thin, typed wrapper around [Dio].
///
/// Guarantees: every call either returns a parsed `T` or throws an
/// [AppException] ([NetworkException], [ServerException], [ParsingException]).
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  String get baseUrl => _dio.options.baseUrl;

  /// Switches the base URL at runtime. Absolute URLs passed as `path` always
  /// bypass it.
  void updateBaseUrl(String baseUrl) => _dio.options.baseUrl = baseUrl;

  /// Calls the Postgres function [name] (`POST rest/v1/rpc/<name>`).
  /// Parameter names must match the SQL argument names exactly.
  Future<T> rpc<T>(
    String name, {
    required ResponseParser<T> parser,
    Map<String, dynamic>? params,
    bool skipAuth = false,
  }) {
    return post<T>(
      ApiConstants.rpc(name),
      data: params ?? const <String, dynamic>{},
      options: skipAuth ? _skipAuth : null,
      parser: parser,
    );
  }

  /// Calls the Edge Function [name] (`POST functions/v1/<name>`).
  /// [data] is a JSON map or a [FormData] for multipart uploads.
  Future<T> invokeFunction<T>(
    String name, {
    required ResponseParser<T> parser,
    Object? data,
    bool skipAuth = false,
  }) {
    return post<T>(
      ApiConstants.function(name),
      data: data ?? const <String, dynamic>{},
      options: skipAuth ? _skipAuth : null,
      parser: parser,
    );
  }

  static final Options _skipAuth = Options(
    extra: {ApiConstants.extraSkipAuth: true},
  );

  Future<T> get<T>(
    String path, {
    required ResponseParser<T> parser,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _request(
      () => _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
      parser,
    );
  }

  Future<T> post<T>(
    String path, {
    required ResponseParser<T> parser,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _request(
      () => _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
      parser,
    );
  }

  Future<T> put<T>(
    String path, {
    required ResponseParser<T> parser,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _request(
      () => _dio.put<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
      parser,
    );
  }

  Future<T> delete<T>(
    String path, {
    required ResponseParser<T> parser,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _request(
      () => _dio.delete<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
      parser,
    );
  }

  Future<T> _request<T>(
    Future<Response<dynamic>> Function() send,
    ResponseParser<T> parser,
  ) async {
    final Response<dynamic> response;
    try {
      response = await send();
    } on DioException catch (e) {
      final error = e.error;
      throw error is AppException ? error : DioErrorMapper.map(e);
    }

    try {
      return parser(_decode(response.data));
    } on AppException {
      rethrow;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to parse ${response.requestOptions.uri}',
        error: error,
        stackTrace: stackTrace,
        tag: 'HTTP',
      );
      throw const ParsingException();
    }
  }

  /// Some endpoints reply with a JSON string body (wrong content-type).
  dynamic _decode(dynamic data) {
    if (data is String) {
      if (data.trim().isEmpty) return null;
      try {
        return jsonDecode(data);
      } on FormatException {
        throw const ParsingException();
      }
    }
    return data;
  }
}
