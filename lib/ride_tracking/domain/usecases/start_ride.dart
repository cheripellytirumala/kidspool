import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../repositories/ride_tracking_repository.dart';

/// Ride Partner starts the ride (`start_ride`).
class StartRide implements UseCase<Unit, String> {
  const StartRide(this._repository);

  final RideTrackingRepository _repository;

  /// [requestId] is `ride_requests.id`.
  @override
  Future<Either<Failure, Unit>> call(String requestId) =>
      _repository.startRide(requestId);
}
