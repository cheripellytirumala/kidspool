import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/ride_request.dart';
import '../repositories/messages_repository.dart';

/// F19c · Rides tab: the user's own requests + the rides they drive.
/// Params: `upcoming` or `past`.
class GetMyRides implements UseCase<List<RideRequest>, String> {
  const GetMyRides(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, List<RideRequest>>> call(String scope) =>
      _repository.getMyRides(scope);
}
