import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/add_kids/domain/entities/grade_age.dart';
import 'package:kidspool/auth/data/data_sources/local/license_reader.dart';
import 'package:kidspool/auth/domain/repositories/auth_repository.dart';
import 'package:kidspool/auth/presentation/providers/auth_flow_provider.dart';
import 'package:kidspool/common/core/services/location_service.dart';
import 'package:kidspool/common/core/services/photo_picker.dart';
import 'package:kidspool/common/domain/entities/picked_address.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Fake implements AuthRepository, LicenseReader {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Geocodes every typed address to one point and counts the calls.
class _Location extends LocationService {
  int calls = 0;

  @override
  Future<ResolvedAddress> geocode({
    required String street,
    required String city,
    required String stateCode,
    required String zip,
  }) async {
    calls++;
    return const ResolvedAddress(latitude: 37.4, longitude: -122.1);
  }
}

Future<AuthFlowProvider> _flow(_Location location) async {
  SharedPreferences.setMockInitialValues({});
  return AuthFlowProvider(
    repository: _Fake(),
    location: location,
    photos: PhotoPicker(),
    preferences: await SharedPreferences.getInstance(),
    licenseReader: _Fake(),
    savedProfile: () async => null,
  );
}

void main() {
  group('GradeAge', () {
    test('16 years in Grade 2 is flagged', () {
      expect(GradeAge.mismatch(age: 16, grade: 'Grade 2'), isNotNull);
    });

    test('typical ages, one younger and two older pass', () {
      expect(GradeAge.mismatch(age: 7, grade: 'Grade 2'), isNull);
      expect(GradeAge.mismatch(age: 6, grade: 'Grade 2'), isNull);
      expect(GradeAge.mismatch(age: 9, grade: 'Grade 2'), isNull);
      expect(GradeAge.mismatch(age: 5, grade: 'Kindergarten'), isNull);
      expect(GradeAge.mismatch(age: 17, grade: 'Grade 12'), isNull);
    });

    test('too young for the grade is flagged too', () {
      expect(GradeAge.mismatch(age: 4, grade: 'Grade 3'), isNotNull);
    });
  });

  group('About you', () {
    test(
      'no errors show until Continue is tried, then each field has one',
      () async {
        final flow = await _flow(_Location());
        expect(flow.errorFor(ProfileField.firstName), isNull);
        flow.setFirstName('Vivek');
        final summary = flow.revealMissing();
        expect(summary, startsWith('Still needed:'));
        expect(flow.errorFor(ProfileField.firstName), isNull);
        expect(flow.errorFor(ProfileField.lastName), 'Enter your last name');
        expect(flow.errorFor(ProfileField.zip), 'Enter your ZIP code');
        expect(flow.errorFor(ProfileField.terms), isNotNull);
        flow.setLastName('L');
        expect(flow.errorFor(ProfileField.lastName), isNull);
      },
    );

    test('the map pin follows the typed address after a pause', () async {
      final location = _Location();
      final flow = await _flow(location);
      fakeAsync((async) {
        flow.setStreet('1 Main St');
        flow.setCity('Palo Alto');
        flow.setStateCode('CA');
        async.elapse(const Duration(milliseconds: 500));
        expect(location.calls, 0, reason: 'still typing');
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(location.calls, 1);
        expect(flow.mapPoint?.latitude, 37.4);
        final before = flow.mapPoint;
        flow.setStreet('2 Main St');
        // The pin stays while typing (removing the map on each keystroke
        // crashed About you); the new address is looked up after a pause.
        expect(flow.mapPoint, same(before), reason: 'pin kept while typing');
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(location.calls, 2, reason: 'new address looked up');
      });
    });

    test('an address picked on the map fills the fields and the pin', () async {
      final flow = await _flow(_Location());
      flow.applyPickedAddress(
        const PickedAddress(
          latitude: 40.7,
          longitude: -74,
          street: '5 Elm St',
          city: 'New York',
          stateCode: 'NY',
          zip: '10001',
        ),
      );
      expect(
        [flow.street, flow.city, flow.stateCode, flow.zip],
        ['5 Elm St', 'New York', 'NY', '10001'],
      );
      expect(flow.mapPoint?.longitude, -74);
    });
  });
}
