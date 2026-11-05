import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../repositories/messages_repository.dart';

/// Ride Partner: "Not this time" — hidden on this device.
class PassRideRequest implements UseCase<Unit, String> {
  const PassRideRequest(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String params) =>
      _repository.passRequest(params);
}
