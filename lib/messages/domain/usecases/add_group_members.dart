import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../repositories/messages_repository.dart';

/// Adds parents to a group (`add_ride_group_members`); any member may.
/// Returns how many were added.
class AddGroupMembers implements UseCase<int, AddGroupMembersParams> {
  const AddGroupMembers(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, int>> call(AddGroupMembersParams params) => _repository
      .addGroupMembers(groupId: params.groupId, memberIds: params.memberIds);
}

class AddGroupMembersParams extends Equatable {
  const AddGroupMembersParams({required this.groupId, required this.memberIds});

  final String groupId;
  final List<String> memberIds;

  @override
  List<Object?> get props => [groupId, memberIds];
}
