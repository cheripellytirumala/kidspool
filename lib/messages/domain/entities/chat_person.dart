import 'package:equatable/equatable.dart';

/// A parent on the other end of a ride or chat (`driver_card_json`,
/// `driver_request_json.parent`, `get_my_ride_chats.other`).
class ChatPerson extends Equatable {
  const ChatPerson({
    this.id,
    required this.firstName,
    this.lastName,
    required this.initials,
    this.phone,
    this.photoUrl,
    this.distanceMiles,
    this.ridesGiven = 0,
    this.kidsAtSchool = const [],
  });

  /// `profiles.id`; `driver_request_json.parent` has none.
  final String? id;
  final String firstName;
  final String? lastName;
  final String initials;

  /// Only once a ride is booked between the two parents.
  final String? phone;

  /// The API has no profile photos for parents yet → initials avatar.
  final String? photoUrl;
  final double? distanceMiles;
  final int ridesGiven;

  /// First names of this parent's kids at the ride's school.
  final List<String> kidsAtSchool;

  /// `Jen P.` (or `Jen`).
  String get shortName {
    final last = lastName?.trim() ?? '';
    return last.isEmpty ? firstName : '$firstName ${last[0]}.';
  }

  @override
  List<Object?> get props => [
    id,
    firstName,
    lastName,
    initials,
    phone,
    photoUrl,
    distanceMiles,
    ridesGiven,
    kidsAtSchool,
  ];
}

/// A kid on a ride request.
class ChatKid extends Equatable {
  const ChatKid({required this.firstName, this.photoUrl, this.photoPath});

  final String firstName;

  /// Signed URL of [photoPath] (own kids only).
  final String? photoUrl;
  final String? photoPath;

  String get initial =>
      firstName.trim().isEmpty ? '?' : firstName.trim()[0].toUpperCase();

  ChatKid withPhotoUrl(String? url) =>
      ChatKid(firstName: firstName, photoPath: photoPath, photoUrl: url);

  @override
  List<Object?> get props => [firstName, photoUrl, photoPath];
}
