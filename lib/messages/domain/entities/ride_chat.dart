import 'package:equatable/equatable.dart';

import 'chat_person.dart';
import 'ride_request.dart';

/// One chat in the Chats tab (`get_my_ride_chats` row). A chat is the pair
/// (request, Ride Partner).
class RideChat extends Equatable {
  const RideChat({
    required this.requestId,
    required this.driverId,
    required this.iAmDriver,
    required this.status,
    required this.other,
    this.lastMessage,
    this.lastAt,
    this.unread = 0,
  });

  final String requestId;
  final String driverId;

  /// The user is the Ride Partner of this chat (else the requesting parent).
  final bool iAmDriver;
  final RideRequestStatus status;
  final ChatPerson other;
  final String? lastMessage;
  final DateTime? lastAt;
  final int unread;

  bool get hasUnread => unread > 0;

  @override
  List<Object?> get props => [
    requestId,
    driverId,
    iAmDriver,
    status,
    other,
    lastMessage,
    lastAt,
    unread,
  ];
}

/// One message (`get_ride_messages` / `send_ride_message`).
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  /// Sent by the signed-in user [myUserId] (unknown user → never mine).
  bool isMine(String? myUserId) =>
      myUserId != null && myUserId.isNotEmpty && senderId == myUserId;

  @override
  List<Object?> get props => [id, senderId, body, createdAt, readAt];
}
