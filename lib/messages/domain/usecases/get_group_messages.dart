import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/ride_group.dart';
import '../repositories/messages_repository.dart';

/// Latest messages of a group, oldest first (`get_ride_group_messages`).
class GetGroupMessages implements UseCase<List<GroupMessage>, String> {
  const GetGroupMessages(this._repository);

  final MessagesRepository _repository;

  /// The signed-in user's id, to tell own messages apart.
  String? get myUserId => _repository.myUserId;

  @override
  Future<Either<Failure, List<GroupMessage>>> call(String params) =>
      _repository.getGroupMessages(params);
}
