import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/add_kids/domain/entities/grade_age.dart';
import 'package:kidspool/add_kids/presentation/providers/add_child_form_provider.dart';
import 'package:kidspool/auth/presentation/screens/vehicle_details_screen.dart';
import 'package:kidspool/common/core/utils/zoned_time.dart';
import 'package:kidspool/profile/domain/entities/my_car.dart';

TextEditingValue _type(String text) => const PlateFormatter().formatEditUpdate(
  TextEditingValue.empty,
  TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  ),
);

void main() {
  group('Your vehicle', () {
    test('plate is typed in capitals and drops special characters', () {
      expect(_type('ts09 ab-12#4!').text, 'TS09 AB-124');
      expect(_type('abcdefghijklmnop').text, hasLength(12));
    });

    test('plate errors always come with a message', () {
      expect(VehicleDetailsScreen.plateError(''), 'Enter your license plate');
      expect(VehicleDetailsScreen.plateError('--'), isNotNull);
      expect(VehicleDetailsScreen.plateError('A'), isNotNull);
      expect(VehicleDetailsScreen.plateError('TS09 AB 1234'), isNull);
    });

    test('year must be a real model year', () {
      final now = DateTime(2026, 11, 24);
      for (final bad in ['2030', '8888', '1950', '202']) {
        expect(
          VehicleDetailsScreen.yearError(bad, now),
          isNotNull,
          reason: bad,
        );
      }
      for (final ok in ['2027', '2026', '1980', '']) {
        expect(VehicleDetailsScreen.yearError(ok, now), isNull, reason: ok);
      }
    });

    test('colours are a fixed list with swatches', () {
      expect(MyCar.colors.map((c) => c.$1), containsAll(['White', 'Silver']));
    });
  });

  group('Add a child', () {
    test('seat follows the age: car seat, booster, belt', () {
      expect(AddChildFormProvider.seatFor(2), SeatNeed.carSeat);
      expect(AddChildFormProvider.seatFor(3), SeatNeed.carSeat);
      expect(AddChildFormProvider.seatFor(4), SeatNeed.booster);
      expect(AddChildFormProvider.seatFor(7), SeatNeed.booster);
      expect(AddChildFormProvider.seatFor(9), SeatNeed.none);
    });

    test('daycare and preschool grades fit toddlers', () {
      expect(AddChildFormProvider.grades.take(2), ['Daycare', 'Preschool']);
      expect(GradeAge.mismatch(age: 2, grade: 'Daycare'), isNull);
      expect(GradeAge.mismatch(age: 0, grade: 'Daycare'), isNull);
      expect(GradeAge.mismatch(age: 2, grade: 'Preschool'), isNull);
      expect(GradeAge.mismatch(age: 9, grade: 'Daycare'), isNotNull);
    });
  });

  group('Ride times', () {
    test('shown on the ride’s own clock, whatever the phone’s zone', () {
      final pickup = DateTime.utc(2026, 11, 24, 16, 20);
      final ny = ZonedTime.inZone(pickup, 'America/New_York');
      expect((ny.hour, ny.minute), (11, 20));
      final india = ZonedTime.inZone(pickup, 'Asia/Kolkata');
      expect((india.hour, india.minute), (21, 50));
    });

    test('unknown zone falls back to the phone’s time', () {
      final t = DateTime.utc(2026, 11, 24, 16, 20);
      expect(ZonedTime.inZone(t, 'Not/AZone'), t.toLocal());
      expect(ZonedTime.inZone(t, null), t.toLocal());
    });
  });
}
