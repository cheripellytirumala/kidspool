import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:kidspool/auth/data/data_sources/local/license_reader.dart';
import 'package:kidspool/auth/domain/entities/license_details.dart';
import 'package:kidspool/auth/domain/repositories/auth_repository.dart';
import 'package:kidspool/auth/presentation/providers/auth_flow_provider.dart';
import 'package:kidspool/auth/presentation/providers/scan_id_provider.dart';
import 'package:kidspool/common/core/error/failures.dart';
import 'package:kidspool/common/core/services/location_service.dart';
import 'package:kidspool/common/core/services/photo_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Server switch [check]; null = the call fails. Reads [license].
class _Fake implements AuthRepository, LicenseReader {
  _Fake({this.check = true, this.license});

  final bool? check;
  final LicenseDetails? license;

  @override
  Future<Either<Failure, bool>> licenseAutoCheck() async =>
      check == null ? const Left(ServerFailure('offline')) : Right(check!);

  @override
  Future<LicenseDetails?> read({
    required String frontPath,
    String? backPath,
  }) async => license;

  @override
  Future<bool> isSameSide(String a, String b) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Photos extends PhotoPicker {
  int n = 0;

  @override
  Future<String?> pick({
    required bool fromCamera,
    bool frontCamera = false,
  }) async => '/tmp/id_${n++}.jpg';
}

/// A flow with "Vivek L" typed, both licence photos taken and read.
Future<AuthFlowProvider> _flow(_Fake fake) async {
  SharedPreferences.setMockInitialValues({});
  final flow =
      AuthFlowProvider(
          repository: fake,
          location: LocationService(),
          photos: _Photos(),
          preferences: await SharedPreferences.getInstance(),
          licenseReader: fake,
          savedProfile: () async => null,
        )
        ..setFirstName('Vivek')
        ..setLastName('L');
  await flow.captureIdSide(IdSide.front, fromCamera: true);
  await flow.captureIdSide(IdSide.back, fromCamera: true);
  await flow.readLicense();
  return flow;
}

const _otherName = LicenseDetails(
  source: LicenseReadSource.barcode,
  firstName: 'Someone',
  lastName: 'Else',
);

void main() {
  test('checks on (default): a name that differs blocks sending', () async {
    final flow = await _flow(_Fake(license: _otherName));
    await flow.loadLicenseAutoCheck();
    expect(flow.licenseAutoCheck, isTrue);
    expect(flow.licenseNameMismatch, isTrue);
    expect(flow.canSubmitLicense, isFalse);
  });

  test('checks off on the server: any read licence can be sent', () async {
    final flow = await _flow(_Fake(check: false, license: _otherName));
    await flow.loadLicenseAutoCheck();
    expect(flow.licenseAutoCheck, isFalse);
    expect(flow.canSubmitLicense, isTrue);
  });

  test('checks off: even an unreadable licence can be sent', () async {
    final flow = await _flow(_Fake(check: false));
    await flow.loadLicenseAutoCheck();
    expect(flow.license, isNull);
    expect(flow.canSubmitLicense, isTrue);
  });

  test('switch unreachable: checks stay on', () async {
    final flow = await _flow(_Fake(check: null, license: _otherName));
    await flow.loadLicenseAutoCheck();
    expect(flow.licenseAutoCheck, isTrue);
    expect(flow.canSubmitLicense, isFalse);
  });

  test('checks on: a matching name can be sent', () async {
    final flow = await _flow(
      _Fake(
        license: const LicenseDetails(
          source: LicenseReadSource.barcode,
          firstName: 'Vivek',
          lastName: 'L',
        ),
      ),
    );
    await flow.loadLicenseAutoCheck();
    expect(flow.canSubmitLicense, isTrue);
  });
}
