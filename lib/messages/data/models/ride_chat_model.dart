import '../../../common/core/utils/json_parser.dart';
import '../../core/utils/messages_format.dart';
import '../../domain/entities/chat_person.dart';
import '../../domain/entities/ride_chat.dart';
import '../../domain/entities/ride_request.dart';

/// JSON → chat entities (`docs/backend/2026-11-03_ride_messages.sql`).
abstract final class RideChatModel {
  /// `get_my_ride_chats` → chats, newest first; rows without ids skipped.
  static List<RideChat> chatsFromJson(Object? json) {
    if (json is! List) return const [];
    return [
      for (final row in json.whereType<Map>())
        ?chatFromJson(Map<String, dynamic>.from(row)),
    ];
  }

  static RideChat? chatFromJson(Map<String, dynamic> json) {
    final requestId = json.readString('requestId');
    final driverId = json.readString('driverId');
    if (requestId == null || driverId == null) return null;
    final other = json['other'] is Map
        ? Map<String, dynamic>.from(json['other'] as Map)
        : const <String, dynamic>{};
    final first = _text(other['firstName']) ?? 'Parent';
    final last = _text(other['lastName']);
    return RideChat(
      requestId: requestId,
      driverId: driverId,
      iAmDriver: json.readBool('iAmDriver') ?? false,
      status: RideRequestStatus.parse(json.readString('status')),
      other: ChatPerson(
        id: _text(other['id']),
        firstName: first,
        lastName: last,
        initials:
            _text(other['initials']) ?? MessagesFormat.initials(first, last),
      ),
      lastMessage: _text(json['lastMessage']),
      lastAt: _time(json['lastAt']),
      unread: json.readInt('unread') ?? 0,
    );
  }

  /// `get_ride_messages` → messages oldest first.
  static List<ChatMessage> messagesFromJson(Object? json) {
    if (json is! List) return const [];
    final list = [
      for (final row in json.whereType<Map>())
        ?messageFromJson(Map<String, dynamic>.from(row)),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// One message (also the `send_ride_message` result).
  static ChatMessage? messageFromJson(Map<String, dynamic> json) {
    final id = json.readString('id');
    final senderId = json.readString('senderId');
    final createdAt = _time(json['createdAt']);
    if (id == null || senderId == null || createdAt == null) return null;
    return ChatMessage(
      id: id,
      senderId: senderId,
      body: json.readString('body') ?? '',
      createdAt: createdAt,
      readAt: _time(json['readAt']),
    );
  }

  static String? _text(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _time(Object? value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
}
