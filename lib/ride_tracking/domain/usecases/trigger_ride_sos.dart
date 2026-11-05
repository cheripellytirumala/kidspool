import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../repositories/ride_tracking_repository.dart';

/// Raises an SOS on the ride (`trigger_sos`).
class TriggerRideSos implements UseCase<Unit, String> {
  const TriggerRideSos(this._repository);

  final RideTrackingRepository _repository;

  /// [requestId] is `ride_requests.id`.
  @override
  Future<Either<Failure, Unit>> call(String requestId) =>
      _repository.triggerSos(requestId);
}
