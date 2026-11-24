import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/common/core/network/auth_token_provider.dart';
import 'package:kidspool/common/core/network/interceptors/auth_interceptor.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.answer);
  final (int, Object) Function(RequestOptions) answer;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    calls++;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final (status, body) = answer(o);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late InMemoryAuthTokenProvider tokens;
  late _Adapter api;
  late _Adapter auth;
  late Dio dio;
  var issued = 0;

  setUp(() async {
    issued = 0;
    tokens = InMemoryAuthTokenProvider();
    final in1h = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    // Looks valid locally, but the server already rejects it.
    await tokens.saveSession(
      AuthSession(accessToken: 'old', refreshToken: 'r0', expiresAt: in1h),
    );
    api = _Adapter(
      (o) => o.headers['Authorization'] == 'Bearer old'
          ? (401, {'message': 'JWT expired'})
          : (200, {'ok': true}),
    );
    auth = _Adapter((o) {
      issued++;
      return (
        200,
        {
          'access_token': 'new$issued',
          'refresh_token': 'r$issued',
          'expires_in': 3600,
        },
      );
    });
    dio = Dio(BaseOptions(baseUrl: 'https://x.supabase.co/'))
      ..httpClientAdapter = api;
    dio.interceptors.add(
      AuthInterceptor(
        tokenProvider: tokens,
        dio: dio,
        supabaseUrl: 'https://x.supabase.co/',
        publishableKey: 'pk',
        refreshDio: Dio(BaseOptions(baseUrl: 'https://x.supabase.co/'))
          ..httpClientAdapter = auth,
      ),
    );
  });

  test('5 requests failing together refresh the session once', () async {
    final results = await Future.wait([
      for (var i = 0; i < 5; i++) dio.post<dynamic>('rest/v1/rpc/f$i'),
    ]);
    expect(results.map((r) => r.statusCode), everyElement(200));
    expect(auth.calls, 1, reason: 'one refresh, not one per request');
    expect(tokens.session?.accessToken, 'new1');
  });

  test('rate-limited refresh (429) is not retried right away', () async {
    auth = _Adapter((_) => (429, {'message': 'rate limit'}));
    dio.interceptors
      ..clear()
      ..add(
        AuthInterceptor(
          tokenProvider: tokens,
          dio: dio,
          supabaseUrl: 'https://x.supabase.co/',
          publishableKey: 'pk',
          refreshDio: Dio(BaseOptions(baseUrl: 'https://x.supabase.co/'))
            ..httpClientAdapter = auth,
        ),
      );
    for (var i = 0; i < 3; i++) {
      await expectLater(
        dio.post<dynamic>('rest/v1/rpc/f'),
        throwsA(isA<DioException>()),
      );
    }
    expect(auth.calls, 1);
    expect(tokens.session, isNotNull, reason: '429 keeps the user signed in');
  });
}
