import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../entities/ride_tracking.dart';

/// Ride day: the requesting parent watches, the Ride Partner drives.
abstract interface class RideTrackingRepository {
  /// The whole ride; [includePath] adds the points driven so far.
  Future<Either<Failure, RideTracking>> getTracking(
    String requestId, {
    bool includePath = false,
  });

  /// Ride Partner — any time while the ride is confirmed.
  Future<Either<Failure, Unit>> startRide(String requestId);

  /// Ride Partner — the kids are in the car.
  Future<Either<Failure, Unit>> markPickedUp(String requestId);

  /// Ride Partner — dropped off at school.
  Future<Either<Failure, RideCompletion>> completeRide(String requestId);

  /// Parent or Ride Partner — raises an SOS on the ride.
  Future<Either<Failure, Unit>> triggerSos(String requestId);

  /// Requesting parent — "Say thank you" once the ride is completed.
  Future<Either<Failure, Unit>> sayThankYou(
    String requestId, {
    required int rating,
  });
}
