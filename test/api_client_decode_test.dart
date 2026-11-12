import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/common/core/error/exceptions.dart';
import 'package:kidspool/common/core/network/api_client.dart';

/// Answers every request with [body] as `application/json`.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.body);
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
    },
  );

  @override
  void close({bool force = false}) {}
}

ApiClient _client(String body) => ApiClient(
  Dio(BaseOptions(baseUrl: 'https://x.test/'))
    ..httpClientAdapter = _Adapter(body),
);

void main() {
  test('a function returning text ("approved") is not an error', () async {
    final value = await _client(
      jsonEncode('approved'),
    ).rpc<String?>('set_my_profile_basics', parser: (json) => json as String?);
    expect(value, 'approved');
  });

  test(
    'JSON objects still decode; a bad shape is still a parsing error',
    () async {
      final map = await _client(
        '{"a":1}',
      ).rpc<int>('f', parser: (json) => (json as Map)['a'] as int);
      expect(map, 1);
      expect(
        () =>
            _client('"x"').rpc<int>('f', parser: (json) => (json as Map)['a']),
        throwsA(isA<ParsingException>()),
      );
    },
  );
}
