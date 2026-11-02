import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../repositories/ride_tracking_repository.dart';

class SayThankYouParams extends Equatable {
  const SayThankYouParams(this.requestId, {required this.rating});

  final String requestId;

  /// 1–5 stars.
  final int rating;

  @override
  List<Object?> get props => [requestId, rating];
}

/// The requesting parent thanks the Ride Partner (`rate_ride` with
/// `thankYou: true`).
class SayThankYou implements UseCase<Unit, SayThankYouParams> {
  const SayThankYou(this._repository);

  final RideTrackingRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(SayThankYouParams params) =>
      _repository.sayThankYou(params.requestId, rating: params.rating);
}
