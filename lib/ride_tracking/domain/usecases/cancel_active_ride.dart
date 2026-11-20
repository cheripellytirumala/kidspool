import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../repositories/ride_tracking_repository.dart';

/// Parent or Ride Partner cancels a started ride before pick-up
/// (`cancel_active_ride`).
class CancelActiveRide {
  const CancelActiveRide(this._repository);

  final RideTrackingRepository _repository;

  Future<Either<Failure, Unit>> call(String requestId, {String? reason}) =>
      _repository.cancelActiveRide(requestId, reason: reason);
}
