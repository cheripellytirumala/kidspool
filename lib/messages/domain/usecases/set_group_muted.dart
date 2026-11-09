import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../repositories/messages_repository.dart';

/// Mutes / unmutes a group's notifications for the user
/// (`set_ride_group_muted`).
class SetGroupMuted implements UseCase<Unit, SetGroupMutedParams> {
  const SetGroupMuted(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(SetGroupMutedParams params) =>
      _repository.setGroupMuted(groupId: params.groupId, muted: params.muted);
}

class SetGroupMutedParams extends Equatable {
  const SetGroupMutedParams({required this.groupId, required this.muted});

  final String groupId;
  final bool muted;

  @override
  List<Object?> get props => [groupId, muted];
}
