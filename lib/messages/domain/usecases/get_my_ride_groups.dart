import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/ride_group.dart';
import '../repositories/messages_repository.dart';

/// The user's ride groups, newest activity first (`get_my_ride_groups`).
class GetMyRideGroups implements UseCase<List<RideGroup>, NoParams> {
  const GetMyRideGroups(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, List<RideGroup>>> call(NoParams params) =>
      _repository.getMyGroups();
}
