import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../repositories/ride_tracking_repository.dart';

/// Ride Partner marks the kids as picked up (`mark_picked_up`), with the
/// requesting parent's 4-digit [pin] when given.
class MarkPickedUp {
  const MarkPickedUp(this._repository);

  final RideTrackingRepository _repository;

  /// [requestId] is `ride_requests.id`.
  Future<Either<Failure, Unit>> call(String requestId, {String? pin}) =>
      _repository.markPickedUp(requestId, pin: pin);
}
