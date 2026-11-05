import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/ride_chat.dart';
import '../repositories/messages_repository.dart';

/// Sends a message in a chat (`send_ride_message`).
class SendRideMessage implements UseCase<ChatMessage, SendRideMessageParams> {
  const SendRideMessage(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, ChatMessage>> call(SendRideMessageParams params) =>
      _repository.sendMessage(
        requestId: params.requestId,
        driverId: params.driverId,
        body: params.body,
      );
}

class SendRideMessageParams extends Equatable {
  const SendRideMessageParams({
    required this.requestId,
    required this.driverId,
    required this.body,
  });

  final String requestId;
  final String driverId;
  final String body;

  @override
  List<Object?> get props => [requestId, driverId, body];
}
