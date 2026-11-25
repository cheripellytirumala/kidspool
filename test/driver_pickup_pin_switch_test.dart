import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:kidspool/common/core/error/failures.dart';
import 'package:kidspool/ride_tracking/core/constants/ride_features.dart';
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

/// Started, kids not picked up yet: the driver's next step is "Picked up".
class _Repo implements RideTrackingRepository {
  _Repo({this.pinRequired = false});
  final bool pinRequired;

  @override
  Future<Either<Failure, RideTracking>> getTracking(
    String requestId, {
    bool includePath = false,
  }) async => Right(
    RideTracking(
      requestId: 'r1',
      status: RideTrackingStatus.inProgress,
      isDriver: true,
      pickupAt: DateTime(2026, 11, 25, 8),
      pickup: const RideStop(label: 'Home'),
      school: const RideStop(label: 'School'),
      pinRequired: pinRequired,
    ),
  );

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

Future<LiveTrackingProvider> _open({
  required bool askDriverForPin,
  bool pinRequired = false,
}) async {
  final repo = _Repo(pinRequired: pinRequired);
  final gps = _Sharing();
  final p = LiveTrackingProvider(
    getRideTracking: GetRideTracking(repo),
    startRide: StartRide(repo),
    markPickedUp: MarkPickedUp(repo),
    completeRide: CompleteRide(repo),
    triggerSos: TriggerRideSos(repo),
    startSharing: StartSharingRideLocation(gps),
    stopSharing: StopSharingRideLocation(gps),
    pollInterval: const Duration(hours: 1),
    askDriverForPin: askDriverForPin,
  );
  await p.open('r1');
  await Future<void>.delayed(Duration.zero);
  return p;
}

void main() {
  test('pick-up PIN entry is hidden for drivers for now', () {
    expect(RideFeatures.driverPickupPin, isFalse);
  });

  test(
    'switch off: "Picked up" goes straight through, no PIN dialog',
    () async {
      final p = await _open(askDriverForPin: false);
      expect(p.driverAction, DriverRideAction.pickedUp);
      expect(p.needsPickupPin, isFalse);
      p.dispose();
    },
  );

  test('switch on: the driver is asked for the PIN', () async {
    final p = await _open(askDriverForPin: true);
    expect(p.needsPickupPin, isTrue);
    p.dispose();
  });

  test('switch off but the server requires the PIN: still asked', () async {
    final p = await _open(askDriverForPin: false, pinRequired: true);
    expect(p.needsPickupPin, isTrue);
    p.dispose();
  });
}
