import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../repositories/messages_repository.dart';

/// Parent cancels their request (`cancel_ride_request`, this day).
class CancelRideRequest implements UseCase<Unit, String> {
  const CancelRideRequest(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String params) =>
      _repository.cancelRideRequest(params);
}
