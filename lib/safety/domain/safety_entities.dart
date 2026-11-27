import 'package:equatable/equatable.dart';

/// Why a person is reported. `name` is what the backend stores.
enum ReportReason {
  childSafety('child_safety', 'Child safety concern'),
  harassment('harassment', 'Harassment or threats'),
  inappropriate('inappropriate', 'Inappropriate messages or photos'),
  unsafeDriving('unsafe_driving', 'Unsafe driving'),
  spam('spam', 'Spam or scam'),
  fakeProfile('fake_profile', 'Fake profile'),
  other('other', 'Something else');

  const ReportReason(this.code, this.label);

  final String code;
  final String label;
}

/// Where the report was made from.
enum ReportContext {
  groupChat('group_chat'),
  rideChat('ride_chat'),
  family('family'),
  member('member');

  const ReportContext(this.code);
  final String code;
}

/// Someone the user blocked.
class BlockedUser extends Equatable {
  const BlockedUser({required this.id, required this.name, this.initials = ''});

  final String id;
  final String name;
  final String initials;

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
    id: json['userId'] as String,
    name: (json['name'] as String?)?.trim().isNotEmpty == true
        ? json['name'] as String
        : 'Member',
    initials: json['initials'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'userId': id,
    'name': name,
    'initials': initials,
  };

  @override
  List<Object?> get props => [id, name, initials];
}
