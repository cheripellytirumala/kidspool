import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/auth/data/data_sources/local/license_reader.dart';
import 'package:kidspool/auth/presentation/widgets/phone_number_formatter.dart';
import 'package:kidspool/auth/domain/entities/license_details.dart';
import 'package:kidspool/common/data/models/my_status_model.dart';
import 'package:kidspool/common/domain/entities/my_status.dart';
import 'package:kidspool/profile/data/repositories/my_car_repository.dart';
import 'package:kidspool/profile/domain/entities/my_car.dart';
import 'package:kidspool/ride_tracking/data/route_service.dart';
import 'package:kidspool/ride_tracking/domain/entities/ride_tracking.dart';

void main() {
  group('license dates', () {
    test('Indian license: day-first dates, Valid Till, Name field', () {
      final d = MlKitLicenseReader.parseFrontText('''
UNION OF INDIA
DRIVING LICENCE
TAMIL NADU TRANSPORT DEPARTMENT
DL No: TN0120190001234
Name: KIRAN KUMAR
S/D/W of: RAMESH KUMAR
DOB: 15-08-1990
Date of Issue: 10-01-2019
Valid Till: 09-01-2039
''');
      expect(d.birthDate, DateTime(1990, 8, 15));
      expect(d.expiryDate, DateTime(2039, 1, 9));
      expect(d.firstName, 'Kiran');
      expect(d.lastName, 'Kumar');
      expect(d.licenseNumber, 'TN0120190001234');
    });

    test('a DOB label without its date never borrows the expiry date', () {
      final d = MlKitLicenseReader.parseFrontText('''
DL D1234567
DOB
EXP 03/04/2031
''');
      expect(d.expiryDate, DateTime(2031, 3, 4));
      expect(d.birthDate, isNull);
    });

    test('US license still reads month-first', () {
      final d = MlKitLicenseReader.parseFrontText('''
DRIVER LICENSE
DOB: 10/12/1988
EXP 01/15/2030
''');
      expect(d.birthDate, DateTime(1988, 10, 12));
      expect(d.expiryDate, DateTime(2030, 1, 15));
    });
  });

  group('license age', () {
    test('under 18 is flagged, adults and unknown are not', () {
      final now = DateTime.now();
      LicenseDetails born(int yearsAgo) => LicenseDetails(
        source: LicenseReadSource.text,
        birthDate: DateTime(now.year - yearsAgo, 1, 1),
      );
      expect(born(16).isUnder18, isTrue);
      expect(born(30).isUnder18, isFalse);
      expect(
        const LicenseDetails(source: LicenseReadSource.text).isUnder18,
        isFalse,
      );
    });
  });

  group('front photo used as the back', () {
    Set<String> words(String s) => s.split(' ').toSet();
    test('same printed text is the same side', () {
      expect(
        MlKitLicenseReader.looksLikeSameText(
          words('DRIVING LICENCE NAME KIRAN KUMAR DOB 1990 VALID TILL 2039'),
          words('DRIVING LICENCE NAME KIRAN KUMAR DOB 1990 VALID 2039 TILL'),
        ),
        isTrue,
      );
    });
    test('front and back text differ', () {
      expect(
        MlKitLicenseReader.looksLikeSameText(
          words('DRIVING LICENCE NAME KIRAN KUMAR DOB 1990 VALID TILL 2039'),
          words('CLASS OF VEHICLE LMV MCWG BLOOD GROUP ADDRESS EMERGENCY'),
        ),
        isFalse,
      );
    });
  });

  group('license badge', () {
    test('an approved rider without a license is not license-verified', () {
      final status = MyStatusModel.fromJson({
        'onboardingStatus': 'approved',
        'driverStatus': 'not_submitted',
      });
      expect(status.isApproved, isTrue);
      expect(status.isLicenseVerified, isFalse);
      expect(status.licenseStatus, OnboardingStatus.notStarted);
    });

    test('an approved license is verified', () {
      final status = MyStatusModel.fromJson({
        'onboardingStatus': 'approved',
        'driverStatus': 'approved',
      });
      expect(status.isLicenseVerified, isTrue);
    });
  });

  group('my car', () {
    test('a 7-seater has room for 6 kids', () {
      const car = MyCar(carSeats: 7, hasBooster: true);
      expect(car.kidSeats, 6);
      expect(car.summary, '7-seater · 6 member seats free · booster');
    });

    test('kid seats free can be fewer than the car has', () {
      const car = MyCar(
        carSeats: 7,
        kidSeats: 3,
        model: 'Honda Odyssey',
        color: 'White',
      );
      expect(car.kidSeats, 3);
      expect(car.title, 'White Honda Odyssey');
    });

    test('parses the server answer, null when no car', () {
      expect(MyCarRepository.parse(null), isNull);
      final car = MyCarRepository.parse({'carSeats': 5, 'hasBooster': false});
      expect(car, const MyCar(carSeats: 5));
      final full = MyCarRepository.parse({
        'carSeats': 7,
        'hasBooster': true,
        'model': 'White Honda City',
        'plateNumber': 'TS09AB1234',
      });
      expect(full?.plateNumber, 'TS09AB1234');
      expect(full?.model, 'White Honda City');
    });

    test('the driver card shows the seats', () {
      const driver = RidePerson(
        id: 'd',
        name: 'Dev S',
        initials: 'DS',
        carModel: 'Honda',
        carSeats: 7,
      );
      expect(driver.vehicleLine, 'Honda · 7-seater');
    });
  });

  test('decodes a Google encoded polyline', () {
    // Google's documented example.
    final points = RouteService.decode('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(points.length, 3);
    expect(points.first.latitude, closeTo(38.5, 1e-6));
    expect(points.first.longitude, closeTo(-120.2, 1e-6));
    expect(points.last.latitude, closeTo(43.252, 1e-6));
    expect(points.last.longitude, closeTo(-126.453, 1e-6));
  });

  test('a typed country code 1 is not part of the number', () {
    expect(UsPhoneNumberFormatter.digitsOf('19999999999'), '9999999999');
    expect(UsPhoneNumberFormatter.digitsOf('1 987 654 3211'), '9876543211');
    expect(UsPhoneNumberFormatter.digitsOf('+1  1999999999'), '999999999');
    expect(UsPhoneNumberFormatter.digitsOf('+1  (999) 999-9999'), '9999999999');
    expect(UsPhoneNumberFormatter.digitsOf('9876543211'), '9876543211');
  });
}
