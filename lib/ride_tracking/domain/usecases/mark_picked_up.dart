import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../repositories/ride_tracking_repository.dart';

/// Ride Partner marks the kids as picked up (`mark_picked_up`).
class MarkPickedUp implements UseCase<Unit, String> {
  const MarkPickedUp(this._repository);

  final RideTrackingRepository _repository;

  /// [requestId] is `ride_requests.id`.
  @override
  Future<Either<Failure, Unit>> call(String requestId) =>
      _repository.markPickedUp(requestId);
}
