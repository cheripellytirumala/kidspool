import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../repositories/messages_repository.dart';

/// Starts a group with the picked parents (`create_ride_group`). Returns
/// the new group's id.
class CreateRideGroup implements UseCase<String, CreateRideGroupParams> {
  const CreateRideGroup(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, String>> call(CreateRideGroupParams params) =>
      _repository.createGroup(
        name: params.name,
        memberIds: params.memberIds,
        schoolId: params.schoolId,
      );
}

class CreateRideGroupParams extends Equatable {
  const CreateRideGroupParams({
    required this.name,
    required this.memberIds,
    this.schoolId,
  });

  final String name;

  /// `profiles.id` of the other parents (the user joins as owner).
  final List<String> memberIds;
  final String? schoolId;

  @override
  List<Object?> get props => [name, memberIds, schoolId];
}
