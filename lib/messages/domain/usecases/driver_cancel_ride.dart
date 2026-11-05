import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../repositories/messages_repository.dart';

/// Ride Partner backs out of a booked ride (`driver_cancel_ride`).
class DriverCancelRide implements UseCase<Unit, String> {
  const DriverCancelRide(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String params) =>
      _repository.driverCancelRide(params);
}
