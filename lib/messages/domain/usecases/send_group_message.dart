import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/ride_group.dart';
import '../repositories/messages_repository.dart';

/// Sends a message to a group (`send_ride_group_message`).
class SendGroupMessage
    implements UseCase<GroupMessage, SendGroupMessageParams> {
  const SendGroupMessage(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, GroupMessage>> call(SendGroupMessageParams params) =>
      _repository.sendGroupMessage(groupId: params.groupId, body: params.body);
}

class SendGroupMessageParams extends Equatable {
  const SendGroupMessageParams({required this.groupId, required this.body});

  final String groupId;
  final String body;

  @override
  List<Object?> get props => [groupId, body];
}
