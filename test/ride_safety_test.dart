import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/common/presentation/theme/app_theme.dart';
import 'package:kidspool/ride_tracking/presentation/widgets/ride_safety_widgets.dart';
import 'package:kidspool/ride_tracking/data/data_sources/remote/ride_tracking_error_messages.dart';
import 'package:kidspool/ride_tracking/data/models/ride_tracking_model.dart';
import 'package:kidspool/ride_tracking/domain/entities/ride_alert.dart';
import 'package:kidspool/ride_tracking/domain/entities/ride_tracking.dart';
import 'package:kidspool/ride_tracking/presentation/widgets/ride_map.dart';

Map<String, dynamic> _ride({
  String status = 'in_progress',
  Map<String, dynamic> extra = const {},
}) => {
  'myRole': 'parent',
  'requestId': 'r1',
  'status': status,
  'pickupAt': '2026-11-20T08:00:00Z',
  'startedAt': '2026-11-20T07:45:00Z',
  'school': {'name': 'Lincoln', 'latitude': 11.0, 'longitude': 76.9},
  'pickupAddress': {'label': 'Home', 'latitude': 11.01, 'longitude': 76.95},
  'driver': {
    'firstName': 'Jen',
    'lastName': 'Park',
    'gender': 'female',
    'vehicle': {
      'model': 'Toyota Innova',
      'plateNumber': 'TN 37 AB 1234',
      'color': 'Silver',
      'year': 2021,
      'carSeats': 7,
      'kidsOnRide': 2,
    },
  },
  ...extra,
};

void main() {
  testWidgets('pick-up PIN dialog: enter the PIN or skip it', (tester) async {
    String? result = 'unset';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await RideSafetyDialogs.askPickupPin(
                  context,
                  parentName: 'Vivek',
                ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Pick-up PIN'), findsOneWidget);
    expect(find.text('Skip PIN'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '0427');
    await tester.pump();
    await tester.tap(find.text('Confirm pick-up'));
    await tester.pumpAndSettle();
    expect(result, '0427');

    // Skipping returns '' (picked up without a PIN).
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip PIN'));
    await tester.pumpAndSettle();
    expect(result, '');
  });

  test('parses PIN, car colour, seats taken and gender (QA #6 #7 #9 #14)', () {
    final t = RideTrackingModel.fromJson(
      _ride(extra: {'pickupPin': '0427', 'pinRequired': false}),
    );
    expect(t.pickupPin, '0427');
    final d = t.driver!;
    expect(d.carDescription, 'Silver 2021 Toyota Innova');
    expect(
      d.vehicleLine,
      'Silver 2021 Toyota Innova · TN 37 AB 1234 · 7-seater',
    );
    expect(d.seatsLine, '2 of 6 member seats taken');
    expect(d.genderLabel, 'Female');
  });

  test('cancel is offered only after start and before pick-up (QA #3)', () {
    expect(RideTrackingModel.fromJson(_ride()).canCancelBeforePickup, isTrue);
    expect(
      RideTrackingModel.fromJson(
        _ride(extra: {'pickedUpAt': '2026-11-20T08:02:00Z'}),
      ).canCancelBeforePickup,
      isFalse,
    );
    expect(
      RideTrackingModel.fromJson(
        _ride(status: 'confirmed'),
      ).canCancelBeforePickup,
      isFalse,
    );
  });

  test('overdue and auto-ended (QA #12)', () {
    final t = RideTrackingModel.fromJson(
      _ride(extra: {'overdueAt': '2026-11-20T09:30:00Z'}),
    );
    expect(t.overdue(now: DateTime.utc(2026, 11, 20, 9)), isFalse);
    expect(t.overdue(now: DateTime.utc(2026, 11, 20, 10)), isTrue);
    final done = RideTrackingModel.fromJson(
      _ride(
        status: 'completed',
        extra: {'autoEndedAt': '2026-11-20T10:45:00Z'},
      ),
    );
    expect(done.autoEnded, isTrue);
    expect(done.overdue(), isFalse);
  });

  test('wrong-PIN copy counts down', () {
    expect(RideTrackingErrorMessages.wrongPin(3), contains('3 tries left'));
    expect(RideTrackingErrorMessages.wrongPin(1), contains('1 try left'));
    expect(RideTrackingErrorMessages.forCode('pin_required'), contains('PIN'));
  });

  test('new notification kinds become ride banners', () {
    expect(RideAlertKind.fromValue('ride_overdue'), RideAlertKind.started);
    expect(RideAlertKind.fromValue('ride_auto_ended'), RideAlertKind.arrived);
    expect(RideAlertKind.fromValue('offer_received'), RideAlertKind.accepted);
  });

  test('snaps a GPS point onto the road', () {
    const road = [GeoPoint(11.0, 76.9), GeoPoint(11.0, 76.91)]; // east-west
    // ~20 m north of the road, halfway along.
    final (p, d) = RideMap.snapToRoute(const GeoPoint(11.00018, 76.905), road);
    expect(d, closeTo(20, 2));
    expect(p.latitude, closeTo(11.0, 1e-6));
    expect(p.longitude, closeTo(76.905, 1e-6));
  });
}
