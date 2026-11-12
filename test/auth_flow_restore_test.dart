import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/auth/data/data_sources/local/license_reader.dart';
import 'package:kidspool/auth/domain/repositories/auth_repository.dart';
import 'package:kidspool/auth/presentation/providers/auth_flow_provider.dart';
import 'package:kidspool/common/core/services/location_service.dart';
import 'package:kidspool/common/core/services/photo_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Unused implements AuthRepository, LocationService, LicenseReader {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<AuthFlowProvider> _flow(SavedProfile? saved) async {
  SharedPreferences.setMockInitialValues({});
  final unused = _Unused();
  return AuthFlowProvider(
    repository: unused,
    location: unused,
    photos: PhotoPicker(),
    preferences: await SharedPreferences.getInstance(),
    licenseReader: unused,
    savedProfile: () async => saved,
  );
}

void main() {
  test('after a restart the name and verified phone come back', () async {
    final flow = await _flow((
      firstName: 'Vivek',
      lastName: 'L',
      phone: '+19876543211',
    ));
    expect(flow.firstName, isEmpty);
    await flow.restoreFromProfile();
    expect(flow.firstName, 'Vivek');
    expect(flow.lastName, 'L');
    expect(flow.internationalPhone, '+1 (987) 654-3211');
  });

  test('what the parent typed is never overwritten', () async {
    final flow = await _flow((
      firstName: 'Vivek',
      lastName: 'L',
      phone: '+19876543211',
    ));
    flow.setFirstName('Viv');
    flow.setPhoneDigits('4155550142');
    await flow.restoreFromProfile();
    expect(flow.firstName, 'Viv');
    expect(flow.lastName, 'L');
    expect(flow.phoneDigits, '4155550142');
  });

  test('no saved profile: nothing changes', () async {
    final flow = await _flow(null);
    await flow.restoreFromProfile();
    expect(flow.firstName, isEmpty);
    expect(flow.internationalPhone, isEmpty);
  });
}
