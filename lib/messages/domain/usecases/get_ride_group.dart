import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/ride_group.dart';
import '../repositories/messages_repository.dart';

/// A group with its members (`get_ride_group`).
class GetRideGroup implements UseCase<RideGroupDetails, String> {
  const GetRideGroup(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, RideGroupDetails>> call(String params) =>
      _repository.getGroup(params);
}
