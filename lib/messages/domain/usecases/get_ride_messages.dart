import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/ride_chat.dart';
import '../repositories/messages_repository.dart';

/// Messages of one chat, oldest first (`get_ride_messages`).
class GetRideMessages implements UseCase<List<ChatMessage>, ChatRef> {
  const GetRideMessages(this._repository);

  final MessagesRepository _repository;

  /// The signed-in user's id, to tell own messages apart.
  String? get myUserId => _repository.myUserId;

  @override
  Future<Either<Failure, List<ChatMessage>>> call(ChatRef params) => _repository
      .getMessages(requestId: params.requestId, driverId: params.driverId);
}

/// A chat: the pair (ride request, Ride Partner).
class ChatRef extends Equatable {
  const ChatRef({required this.requestId, required this.driverId});

  final String requestId;
  final String driverId;

  @override
  List<Object?> get props => [requestId, driverId];
}
