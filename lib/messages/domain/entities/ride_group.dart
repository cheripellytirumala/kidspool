import 'package:equatable/equatable.dart';

/// One ride group in the Chats tab (`get_my_ride_groups` row): a standing
/// set of families sharing a route, with one shared chat.
class RideGroup extends Equatable {
  const RideGroup({
    required this.id,
    required this.name,
    this.memberCount = 0,
    this.unread = 0,
    this.muted = false,
    this.lastMessage,
    this.lastAt,
  });

  final String id;
  final String name;
  final int memberCount;
  final int unread;

  /// Notifications muted for the signed-in user.
  final bool muted;

  /// "Ben: See you at 8" or a system line ("Ava joined").
  final String? lastMessage;
  final DateTime? lastAt;

  bool get hasUnread => unread > 0;

  /// "6 members".
  String get membersLabel => RideGroupDetails.membersText(memberCount);

  @override
  List<Object?> get props => [
    id,
    name,
    memberCount,
    unread,
    muted,
    lastMessage,
    lastAt,
  ];
}

/// A group with its members (`get_ride_group`).
class RideGroupDetails extends Equatable {
  const RideGroupDetails({
    required this.id,
    required this.name,
    this.schoolName,
    this.muted = false,
    this.maxMembers = 8,
    this.members = const [],
  });

  final String id;
  final String name;
  final String? schoolName;
  final bool muted;
  final int maxMembers;
  final List<RideGroupMember> members;

  int get memberCount => members.length;

  /// Whether the signed-in parent is the group's admin (its creator).
  bool get iAmOwner => members.any((m) => m.isMe && m.isOwner);

  /// Families that can still be added.
  int get remainingSlots =>
      (maxMembers - members.length).clamp(0, maxMembers).toInt();

  bool get isFull => remainingSlots == 0;

  static String membersText(int count) =>
      count == 1 ? '1 member' : '$count members';

  RideGroupDetails copyWith({String? name, bool? muted}) => RideGroupDetails(
    id: id,
    name: name ?? this.name,
    schoolName: schoolName,
    muted: muted ?? this.muted,
    maxMembers: maxMembers,
    members: members,
  );

  @override
  List<Object?> get props => [id, name, schoolName, muted, maxMembers, members];
}

/// A group member, or a parent who could be added
/// (`get_ride_group_candidates`). First names only, never contact details.
class RideGroupMember extends Equatable {
  const RideGroupMember({
    required this.id,
    required this.firstName,
    required this.initials,
    this.isOwner = false,
    this.isMe = false,
    this.kids = const [],
  });

  /// `profiles.id`.
  final String id;
  final String firstName;
  final String initials;
  final bool isOwner;
  final bool isMe;

  /// Kids' first names.
  final List<String> kids;

  @override
  List<Object?> get props => [id, firstName, initials, isOwner, isMe, kids];
}

enum GroupMessageKind {
  text,

  /// "Vivek created the group", "Ava left" — no sender.
  system;

  static GroupMessageKind parse(String? value) =>
      value == 'system' ? system : text;
}

/// The sender of a group message.
class GroupSender extends Equatable {
  const GroupSender({
    required this.id,
    required this.firstName,
    required this.initials,
  });

  final String id;
  final String firstName;
  final String initials;

  @override
  List<Object?> get props => [id, firstName, initials];
}

/// One message in a group chat (`get_ride_group_messages` /
/// `send_ride_group_message`).
class GroupMessage extends Equatable {
  const GroupMessage({
    required this.id,
    required this.kind,
    required this.body,
    required this.createdAt,
    this.sender,
  });

  final String id;
  final GroupMessageKind kind;
  final String body;
  final DateTime createdAt;

  /// Null for system lines.
  final GroupSender? sender;

  bool get isSystem => kind == GroupMessageKind.system || sender == null;

  /// Sent by the signed-in user [myUserId] (unknown user → never mine).
  bool isMine(String? myUserId) =>
      !isSystem &&
      myUserId != null &&
      myUserId.isNotEmpty &&
      sender?.id == myUserId;

  @override
  List<Object?> get props => [id, kind, body, createdAt, sender];
}
