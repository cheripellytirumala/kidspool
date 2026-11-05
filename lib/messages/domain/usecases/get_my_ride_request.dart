import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/ride_request.dart';
import '../repositories/messages_repository.dart';

/// The user's own request with offers (`get_ride_request`).
class GetMyRideRequest implements UseCase<RideRequest, String> {
  const GetMyRideRequest(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, RideRequest>> call(String params) =>
      _repository.getMyRequest(params);
}
