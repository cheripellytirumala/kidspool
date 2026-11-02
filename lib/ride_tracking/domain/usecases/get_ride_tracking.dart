import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/ride_tracking.dart';
import '../repositories/ride_tracking_repository.dart';

class GetRideTrackingParams extends Equatable {
  const GetRideTrackingParams(this.requestId, {this.includePath = false});

  final String requestId;
  final bool includePath;

  @override
  List<Object?> get props => [requestId, includePath];
}

/// Loads the live state of a ride (`get_ride_tracking`).
class GetRideTracking implements UseCase<RideTracking, GetRideTrackingParams> {
  const GetRideTracking(this._repository);

  final RideTrackingRepository _repository;

  @override
  Future<Either<Failure, RideTracking>> call(GetRideTrackingParams params) =>
      _repository.getTracking(
        params.requestId,
        includePath: params.includePath,
      );
}
