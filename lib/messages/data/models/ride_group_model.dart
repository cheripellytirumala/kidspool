import '../../../common/core/utils/json_parser.dart';
import '../../core/constants/messages_api_constants.dart';
import '../../core/utils/messages_format.dart';
import '../../domain/entities/ride_group.dart';

/// JSON → ride group entities (`docs/backend/2026-11-09_ride_groups.sql`).
abstract final class RideGroupModel {
  /// `get_my_ride_groups` → groups, newest first; rows without ids skipped.
  static List<RideGroup> groupsFromJson(Object? json) {
    if (json is! List) return const [];
    final list = [
      for (final row in json.whereType<Map>())
        ?groupFromJson(Map<String, dynamic>.from(row)),
    ];
    list.sort((a, b) => _newestFirst(a.lastAt, b.lastAt));
    return list;
  }

  static RideGroup? groupFromJson(Map<String, dynamic> json) {
    final id = _text(json['id']);
    if (id == null) return null;
    return RideGroup(
      id: id,
      name: _text(json['name']) ?? 'Ride group',
      memberCount: json.readInt('memberCount') ?? 0,
      unread: json.readInt('unread') ?? 0,
      muted: json.readBool('muted') ?? false,
      lastMessage: _text(json['lastMessage']),
      lastAt: _time(json['lastAt']),
    );
  }

  /// `get_ride_group`.
  static RideGroupDetails? detailsFromJson(Object? json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final id = _text(map['id']);
    if (id == null) return null;
    return RideGroupDetails(
      id: id,
      name: _text(map['name']) ?? 'Ride group',
      schoolName: _text(map['schoolName']),
      muted: map.readBool('muted') ?? false,
      maxMembers:
          map.readInt('maxMembers') ?? MessagesApiConstants.maxGroupMembers,
      members: membersFromJson(map['members']),
    );
  }

  /// Members (in server order) or candidates.
  static List<RideGroupMember> membersFromJson(Object? json) {
    if (json is! List) return const [];
    return [
      for (final row in json.whereType<Map>())
        ?memberFromJson(Map<String, dynamic>.from(row)),
    ];
  }

  static RideGroupMember? memberFromJson(Map<String, dynamic> json) {
    final id = _text(json['id']);
    if (id == null) return null;
    final first = _text(json['firstName']) ?? 'Parent';
    final kids = json['kids'];
    return RideGroupMember(
      id: id,
      firstName: first,
      initials: _text(json['initials']) ?? MessagesFormat.initials(first),
      isOwner: json.readString('role') == 'owner',
      isMe: json.readBool('isMe') ?? false,
      kids: kids is List ? [for (final k in kids) ?_text(k)] : const <String>[],
    );
  }

  /// `get_ride_group_messages` → messages oldest first.
  static List<GroupMessage> messagesFromJson(Object? json) {
    if (json is! List) return const [];
    return [
      for (final row in json.whereType<Map>())
        ?messageFromJson(Map<String, dynamic>.from(row)),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// One message (also the `send_ride_group_message` result).
  static GroupMessage? messageFromJson(Map<String, dynamic> json) {
    final id = _text(json['id']);
    final createdAt = _time(json['createdAt']);
    if (id == null || createdAt == null) return null;
    final sender = json['sender'];
    GroupSender? from;
    if (sender is Map) {
      final s = Map<String, dynamic>.from(sender);
      final senderId = _text(s['id']);
      if (senderId != null) {
        final first = _text(s['firstName']) ?? 'Parent';
        from = GroupSender(
          id: senderId,
          firstName: first,
          initials: _text(s['initials']) ?? MessagesFormat.initials(first),
        );
      }
    }
    return GroupMessage(
      id: id,
      kind: from == null
          ? GroupMessageKind.system
          : GroupMessageKind.parse(json.readString('kind')),
      body: json.readString('body') ?? '',
      createdAt: createdAt,
      sender: from,
    );
  }

  /// `create_ride_group` → `{id}`.
  static String? idFromJson(Object? json) =>
      json is Map ? _text(json['id']) : null;

  static int _newestFirst(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }

  static String? _text(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _time(Object? value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
}
