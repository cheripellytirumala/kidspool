import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kidspool/ride_tracking/data/data_sources/local/ride_location_data_source.dart';
import 'package:fpdart/fpdart.dart';
import 'package:kidspool/common/core/error/failures.dart';
import 'package:kidspool/ride_tracking/domain/entities/ride_tracking.dart';
import 'package:kidspool/ride_tracking/domain/repositories/ride_location_sharing.dart';
import 'package:kidspool/ride_tracking/domain/repositories/ride_tracking_repository.dart';
import 'package:kidspool/ride_tracking/domain/usecases/complete_ride.dart';
import 'package:kidspool/ride_tracking/domain/usecases/get_ride_tracking.dart';
import 'package:kidspool/ride_tracking/domain/usecases/mark_picked_up.dart';
import 'package:kidspool/ride_tracking/domain/usecases/start_ride.dart';
import 'package:kidspool/ride_tracking/domain/usecases/start_sharing_ride_location.dart';
import 'package:kidspool/ride_tracking/domain/usecases/stop_sharing_ride_location.dart';
import 'package:kidspool/ride_tracking/domain/usecases/trigger_ride_sos.dart';
import 'package:kidspool/ride_tracking/presentation/providers/live_tracking_provider.dart';

/// Drop-off: Doon Public School, Coimbatore.
const _school = GeoPoint(10.9956443, 76.9781608);

class _Repo implements RideTrackingRepository {
  int completes = 0;

  RideTracking get tracking => RideTracking(
    requestId: 'r1',
    status: completes > 0
        ? RideTrackingStatus.completed
        : RideTrackingStatus.inProgress,
    isDriver: true,
    pickupAt: DateTime(2026, 11, 12, 8),
    pickedUpAt: DateTime(2026, 11, 12, 8, 5),
    pickup: const RideStop(label: 'Home'),
    school: const RideStop(label: 'Doon Public School', point: _school),
  );

  @override
  Future<Either<Failure, RideTracking>> getTracking(
    String requestId, {
    bool includePath = false,
  }) async => Right(tracking);

  @override
  Future<Either<Failure, RideCompletion>> completeRide(String requestId) async {
    completes++;
    return const Right(RideCompletion());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sharing implements RideLocationSharing {
  @override
  String? requestId;
  @override
  ({double latitude, double longitude})? lastPosition;
  @override
  void start(String id) => requestId = id;
  @override
  void stop() => requestId = null;
}

LiveTrackingProvider _provider(_Repo repo, _Sharing gps) =>
    LiveTrackingProvider(
      getRideTracking: GetRideTracking(repo),
      startRide: StartRide(repo),
      markPickedUp: MarkPickedUp(repo),
      completeRide: CompleteRide(repo),
      triggerSos: TriggerRideSos(repo),
      startSharing: StartSharingRideLocation(gps),
      stopSharing: StopSharingRideLocation(gps),
      driverPosition: () => gps.lastPosition,
      pollInterval: const Duration(hours: 1),
    );

void main() {
  test('far from the drop-off: no auto drop-off, button still works', () async {
    final repo = _Repo();
    // ~1.1 km north of the school.
    final gps = _Sharing()
      ..lastPosition = (latitude: 11.0056, longitude: 76.9781608);
    final p = _provider(repo, gps);
    await p.open('r1');
    await Future<void>.delayed(Duration.zero);
    expect(p.driverAction, DriverRideAction.complete);
    expect(p.metersToDropoff, greaterThan(1000));
    expect(p.canDropOff, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(repo.completes, 0); // not automatic this far away
    expect(await p.runDriverAction(), isNull); // the button drops off
    expect(repo.completes, 1);
    p.dispose();
  });

  test('within 100 m: drops off by itself, once', () async {
    final repo = _Repo();
    // ~55 m from the school.
    final gps = _Sharing()
      ..lastPosition = (latitude: 10.9961443, longitude: 76.9781608);
    final p = _provider(repo, gps);
    await p.open('r1');
    for (var i = 0; i < 50 && !p.autoDroppedOff; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(repo.completes, 1);
    expect(p.autoDroppedOff, isTrue);
    expect(p.driverAction, isNull); // ride is over
    p.dispose();
  });

  test('no GPS fix: the button still works so the ride can end', () async {
    final repo = _Repo();
    final p = _provider(repo, _Sharing());
    await p.open('r1');
    expect(p.metersToDropoff, isNull);
    expect(p.canDropOff, isTrue);
    expect(repo.completes, 0); // never automatic without a position
    p.dispose();
  });

  testWidgets('in the background: drops off when the car gets within 100 m', (
    tester,
  ) async {
    final repo = _Repo();
    final gps = _Sharing()
      ..lastPosition = (latitude: 11.0056, longitude: 76.9781608); // ~1.1 km
    final p = _provider(repo, gps);
    await p.open('r1');
    await tester.pump();
    expect(repo.completes, 0);

    p.pause(); // app to the background; GPS keeps running
    gps.lastPosition = (latitude: 10.9961443, longitude: 76.9781608); // ~55 m
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(milliseconds: 50));
    expect(repo.completes, 1);
    p.dispose();
  });

  test('ride GPS keeps running in the background on iOS and Android', () {
    final ios = RideLocationDataSourceImpl.rideSettings(TargetPlatform.iOS);
    expect(ios, isA<AppleSettings>());
    ios as AppleSettings;
    expect(ios.allowBackgroundLocationUpdates, isTrue);
    expect(ios.showBackgroundLocationIndicator, isTrue);
    expect(ios.pauseLocationUpdatesAutomatically, isFalse);

    final android = RideLocationDataSourceImpl.rideSettings(
      TargetPlatform.android,
    );
    expect(android, isA<AndroidSettings>());
    android as AndroidSettings;
    expect(android.foregroundNotificationConfig?.setOngoing, isTrue);
    expect(
      android.foregroundNotificationConfig?.notificationTitle,
      'KidPool is sharing your location',
    );
  });
}
