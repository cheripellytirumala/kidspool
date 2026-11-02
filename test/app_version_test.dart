import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/core/config/environment.dart';
import 'package:kidspool/core/error/failures.dart';
import 'package:kidspool/core/network/api_client.dart';
import 'package:kidspool/core/network/auth_token_provider.dart';
import 'package:kidspool/core/network/dio_client.dart';
import 'package:kidspool/data/data_sources/local/app_version_local_data_source.dart';
import 'package:kidspool/data/data_sources/remote/app_version_remote_data_source.dart';
import 'package:kidspool/data/repositories/app_version_repository_impl.dart';
import 'package:kidspool/domain/usecases/get_app_version.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sample = {
  'payment_status': 1,
  'product_status': 1,
  'payment_message': 'Dashboard',
  'product_message': 'Dashboard',
  'api_base_url': 'https://groceriesapidev.ebounti.com/api/',
  'version': '1.9.0',
  'App_Link': 'https://apps.apple.com/us/app/id1511700628',
  'deployment_status': '1',
  'user_details_flag': null,
  'search_radius': '20',
  'distance_radius_filters': [
    {'radius': 5},
    {'radius': 10},
    {'radius': 15},
    {'radius': 20},
    {'radius': 25},
  ],
  'is_force_payment_page': '0',
  'status': 1,
};

const _params = GetAppVersionParams(
  roleId: 1,
  device: 'ios',
  versionNumber: '2.0',
);

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

Future<(AppVersionRepositoryImpl, _FakeAdapter)> _build(
  ResponseBody Function(RequestOptions) handler,
) async {
  SharedPreferences.setMockInitialValues({});
  final dio = DioClient.create(
    config: EnvConfig.of(Environment.production),
    tokenProvider: InMemoryAuthTokenProvider(),
  );
  final adapter = _FakeAdapter(handler);
  dio.httpClientAdapter = adapter;
  final repo = AppVersionRepositoryImpl(
    remoteDataSource: AppVersionRemoteDataSourceImpl(ApiClient(dio)),
    localDataSource: AppVersionLocalDataSourceImpl(
      await SharedPreferences.getInstance(),
    ),
  );
  return (repo, adapter);
}

void main() {
  test('parses response, sends query params, maps to entity', () async {
    final (repo, adapter) = await _build((_) => _json(_sample));

    final result = await repo.getAppVersion(_params);
    final entity = result.getOrElse((f) => throw f);

    expect(adapter.lastRequest!.method, 'POST');
    expect(
      adapter.lastRequest!.uri.toString(),
      'https://admin.ebounti.com/api/getAppVersion?role_id=1&device=ios&version_number=2.0',
    );
    expect(entity.latestVersion, '1.9.0');
    expect(entity.deploymentStatus, '1');
    expect(entity.searchRadius, 20);
    expect(entity.isForcePaymentPage, isFalse);
    expect(entity.userDetailsFlag, isNull);
    expect(entity.distanceRadiusFilters.map((e) => e.radius), [
      5,
      10,
      15,
      20,
      25,
    ]);
  });

  test('status != 1 becomes ServerFailure', () async {
    final (repo, _) = await _build(
      (_) => _json({'status': 0, 'message': 'Nope'}),
    );
    final result = await repo.getAppVersion(_params);
    expect(result.getLeft().toNullable(), const ServerFailure('Nope'));
  });

  test('HTTP 500 becomes ServerFailure with status code', () async {
    final (repo, _) = await _build((_) => _json({}, 500));
    final failure = (await repo.getAppVersion(_params)).getLeft().toNullable();
    expect(failure, isA<ServerFailure>());
    expect(failure!.statusCode, 500);
  });

  test('malformed body becomes ParsingFailure', () async {
    final (repo, _) = await _build((_) => _json([1, 2, 3]));
    final failure = (await repo.getAppVersion(_params)).getLeft().toNullable();
    expect(failure, isA<ParsingFailure>());
  });

  test('network error falls back to cache, else NetworkFailure', () async {
    var offline = false;
    final (repo, _) = await _build((o) {
      if (offline) {
        throw DioException.connectionError(
          requestOptions: o,
          reason: 'offline',
        );
      }
      return _json(_sample);
    });

    offline = true;
    final noCache = (await repo.getAppVersion(_params)).getLeft().toNullable();
    expect(noCache, isA<NetworkFailure>());

    offline = false;
    await repo.getAppVersion(_params); // populates cache
    offline = true;
    final cached = await repo.getAppVersion(_params);
    expect(cached.isRight(), isTrue);
  });
}
