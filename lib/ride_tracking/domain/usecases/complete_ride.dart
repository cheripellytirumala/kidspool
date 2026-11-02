import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/ride_tracking.dart';
import '../repositories/ride_tracking_repository.dart';

/// Ride Partner confirms the drop-off at school (`complete_ride`).
class CompleteRide implements UseCase<RideCompletion, String> {
  const CompleteRide(this._repository);

  final RideTrackingRepository _repository;

  /// [requestId] is `ride_requests.id`.
  @override
  Future<Either<Failure, RideCompletion>> call(String requestId) =>
      _repository.completeRide(requestId);
}
