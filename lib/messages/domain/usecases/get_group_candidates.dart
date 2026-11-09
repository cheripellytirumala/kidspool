import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/ride_group.dart';
import '../repositories/messages_repository.dart';

/// Parents the user may add to a group (`get_ride_group_candidates`);
/// a null group id lists them for a new group.
class GetGroupCandidates implements UseCase<List<RideGroupMember>, String?> {
  const GetGroupCandidates(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, List<RideGroupMember>>> call(String? params) =>
      _repository.getGroupCandidates(params);
}
