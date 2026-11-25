import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/auth/data/data_sources/local/license_reader.dart';
import 'package:kidspool/auth/domain/repositories/auth_repository.dart';
import 'package:kidspool/auth/presentation/providers/auth_flow_provider.dart';
import 'package:kidspool/common/core/services/location_service.dart';
import 'package:kidspool/common/core/services/photo_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Unused implements AuthRepository, LicenseReader {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Device location / geocoder stand-in.
class _FakeLocation implements LocationService {
  Object? currentError;
  int geocodes = 0;

  @override
  Future<ResolvedAddress> currentAddress() async {
    if (currentError != null) throw currentError!;
    return const ResolvedAddress(
      latitude: 37.33,
      longitude: -122.0,
      street: '1 Apple Park Way',
      city: 'Cupertino',
      stateCode: 'CA',
      zip: '95014',
    );
  }

  @override
  Future<ResolvedAddress> geocode({
    required String street,
    required String city,
    required String stateCode,
    required String zip,
  }) async {
    geocodes++;
    return ResolvedAddress(
      latitude: 40.0 + geocodes,
      longitude: -74.0,
      street: street,
      city: city,
      stateCode: stateCode,
      zip: zip,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(AuthFlowProvider, _FakeLocation)> _flow() async {
  SharedPreferences.setMockInitialValues({});
  final location = _FakeLocation();
  final unused = _Unused();
  final prefs = await SharedPreferences.getInstance();
  return (
    AuthFlowProvider(
      repository: unused,
      location: location,
      photos: PhotoPicker(),
      preferences: prefs,
      licenseReader: unused,
    ),
    location,
  );
}

void main() {
  test('the home pin stays on the map while the address is typed', () async {
    final (flow, _) = await _flow();
    await flow.useCurrentLocation();
    final pin = flow.mapPoint;
    expect(pin, isNotNull);

    // Typing must not remove the map (that tore the native map down on
    // every keystroke and crashed the screen when it came back).
    flow.setStreet('1 Apple Park Wa');
    flow.setStreet('1 Apple Park W');
    expect(flow.mapPoint, same(pin));
  });

  test('the pin moves to the typed address once typing pauses', () {
    fakeAsync((async) {
      late AuthFlowProvider flow;
      _flow().then((r) => flow = r.$1);
      async.flushMicrotasks();

      flow.setCity('New York');
      flow.setZip('10001');
      flow.setStreet('5');
      flow.setStreet('5 Av');
      flow.setStreet('5 Ave');
      expect(flow.mapPoint, isNull);
      async.elapse(const Duration(seconds: 1));
      expect(flow.mapPoint, isNotNull);
      expect(flow.mapPoint!.street, '5 Ave');
    });
  });

  test('a location plugin failure becomes a message, not a crash', () async {
    final (flow, location) = await _flow();
    location.currentError = PlatformException(code: 'PERMISSION_DENIED');
    final error = await flow.useCurrentLocation();
    expect(error, isNotNull);
    expect(flow.isLocating, isFalse);
  });
}
