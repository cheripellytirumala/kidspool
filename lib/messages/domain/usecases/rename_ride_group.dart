import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../repositories/messages_repository.dart';

/// Renames a group (`rename_ride_group`, 1–60 characters).
class RenameRideGroup implements UseCase<Unit, RenameRideGroupParams> {
  const RenameRideGroup(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(RenameRideGroupParams params) =>
      _repository.renameGroup(groupId: params.groupId, name: params.name);
}

class RenameRideGroupParams extends Equatable {
  const RenameRideGroupParams({required this.groupId, required this.name});

  final String groupId;
  final String name;

  @override
  List<Object?> get props => [groupId, name];
}
