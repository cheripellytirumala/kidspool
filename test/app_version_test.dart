import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/auth/data/data_sources/local/license_reader.dart';
import 'package:kidspool/common/core/config/environment.dart';
import 'package:kidspool/common/core/constants/api_constants.dart';
import 'package:kidspool/common/core/error/error_handler.dart';
import 'package:kidspool/common/core/error/failures.dart';
import 'package:kidspool/common/core/network/api_client.dart';
import 'package:kidspool/common/core/network/auth_token_provider.dart';
import 'package:kidspool/common/core/network/dio_client.dart';
import 'package:kidspool/onboarding/data/data_sources/local/app_version_local_data_source.dart';
import 'package:kidspool/onboarding/data/data_sources/remote/app_version_remote_data_source.dart';
import 'package:kidspool/onboarding/data/repositories/app_version_repository_impl.dart';
import 'package:kidspool/onboarding/domain/usecases/get_app_version.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _params = GetAppVersionParams(platform: 'ios', appVersion: '1.0.1');

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  RequestOptions get lastRequest => requests.last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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

final _config = EnvConfig.of(Environment.production);

Future<(AppVersionRepositoryImpl, _FakeAdapter)> _build(
  ResponseBody Function(RequestOptions) handler,
) async {
  SharedPreferences.setMockInitialValues({});
  final dio = DioClient.create(
    config: _config,
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
  group('check_app_version', () {
    test('calls the RPC with the publishable key and no token', () async {
      final (repo, adapter) = await _build((_) => _json({'status': 'ok'}));

      final entity = (await repo.getAppVersion(
        _params,
      )).getOrElse((f) => throw f);

      final request = adapter.lastRequest;
      expect(request.method, 'POST');
      expect(
        request.uri.toString(),
        '${_config.supabaseUrl}rest/v1/rpc/check_app_version',
      );
      expect(request.data, {'platform': 'ios', 'appVersion': '1.0.1'});
      expect(
        request.headers[ApiConstants.headerApiKey],
        _config.publishableKey,
      );
      expect(request.headers[ApiConstants.headerAuthorization], isNull);
      expect(entity.isUpdateRequired, isFalse);
    });

    test('force_update maps to isUpdateRequired', () async {
      final (repo, _) = await _build(
        (_) => _json({
          'status': 'force_update',
          'minSupportedVersion': '2.0.0',
          'storeUrl': 'https://apps.apple.com/app/id1',
          'message': 'Please update.',
        }),
      );
      final entity = (await repo.getAppVersion(
        _params,
      )).getOrElse((f) => throw f);
      expect(entity.isUpdateRequired, isTrue);
      expect(entity.minSupportedVersion, '2.0.0');
      expect(entity.message, 'Please update.');
    });

    test('malformed body becomes ParsingFailure', () async {
      final (repo, _) = await _build((_) => _json([1, 2, 3]));
      final failure = (await repo.getAppVersion(
        _params,
      )).getLeft().toNullable();
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
        return _json({'status': 'ok'});
      });

      offline = true;
      final noCache = (await repo.getAppVersion(
        _params,
      )).getLeft().toNullable();
      expect(noCache, isA<NetworkFailure>());

      offline = false;
      await repo.getAppVersion(_params); // populates cache
      offline = true;
      expect((await repo.getAppVersion(_params)).isRight(), isTrue);
    });
  });

  group('Supabase error mapping', () {
    Future<Failure> failureFor(ResponseBody body) async {
      final dio = DioClient.create(
        config: _config,
        tokenProvider: InMemoryAuthTokenProvider(),
      )..httpClientAdapter = _FakeAdapter((_) => body);
      final result = await ErrorHandler.guard(
        () => ApiClient(dio).rpc<void>('x', parser: (_) {}),
      );
      return result.getLeft().toNullable()!;
    }

    test('RPC error: code from `message`, friendly text', () async {
      final failure = await failureFor(
        _json({
          'code': 'PT409',
          'message': 'role_already_set',
          'details': null,
        }, 409),
      );
      expect(failure.code, 'role_already_set');
      expect(failure.statusCode, 409);
    });

    test('Edge Function error: code from `error`, extra fields kept', () async {
      final failure = await failureFor(
        _json({'error': 'resend_too_soon', 'retryAfter': 12}, 429),
      );
      expect(failure.code, 'resend_too_soon');
      expect(failure.data['retryAfter'], 12);
      expect(failure.message, contains('wait'));
    });

    test('missing_field names the field', () async {
      final failure = await failureFor(
        _json({'error': 'missing_field', 'field': 'schoolIdCard'}, 400),
      );
      expect(failure.message, 'Please add the school ID card photo.');
    });
  });

  group('license text parsing (ML Kit fallback)', () {
    test('reads number, dates, names and state from the front', () {
      const text = '''
CALIFORNIA
DRIVER LICENSE
DL D1234567
EXP 08/12/2029
LN MITCHELL
FN SARAH JANE
DOB 03/14/1988
''';
      final details = MlKitLicenseReader.parseFrontText(text);
      expect(details.licenseNumber, 'D1234567');
      expect(details.maskedNumber, 'D•••567');
      expect(details.expiryDate, DateTime(2029, 8, 12));
      expect(details.birthDate, DateTime(1988, 3, 14));
      expect(details.lastName, 'Mitchell');
      expect(details.firstName, 'Sarah Jane');
      expect(details.state, 'CA');
      expect(details.isExpired, isFalse);
    });

    test('Arkansas is not read as Kansas; expired is flagged', () {
      final details = MlKitLicenseReader.parseFrontText(
        'ARKANSAS\nEXP 01/01/2020\n',
      );
      expect(details.state, 'AR');
      expect(details.isExpired, isTrue);
    });
  });
}
