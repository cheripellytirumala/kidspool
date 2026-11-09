import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../repositories/messages_repository.dart';

/// Leaves a group (`leave_ride_group`).
class LeaveRideGroup implements UseCase<Unit, String> {
  const LeaveRideGroup(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String params) =>
      _repository.leaveGroup(params);
}
