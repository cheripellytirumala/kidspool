import 'package:equatable/equatable.dart';

import '../../../add_kids/domain/entities/child.dart';
import '../../../common/domain/entities/my_status.dart';
import '../../../messages/domain/entities/ride_chat.dart';
import 'profile_details.dart';
import 'ride_mode.dart';
import 'saved_address.dart';

/// Everything S18 · Profile shows. Only [status] is required; the other
/// sections load independently and carry their own error message.
class ProfileOverview extends Equatable {
  const ProfileOverview({
    required this.status,
    required this.rideMode,
    this.details = const ProfileDetails(),
    this.kids = const [],
    this.kidsError,
    this.addresses = const [],
    this.addressesError,
    this.rideGroups = const [],
  });

  /// `get_my_status`: name, role, ID review state.
  final MyStatus status;
  final RideMode rideMode;
  final ProfileDetails details;

  final List<Child> kids;
  final String? kidsError;

  /// Default first.
  final List<SavedAddress> addresses;
  final String? addressesError;

  /// Ride chats, newest first ("Ride groups").
  final List<RideChat> rideGroups;

  String get fullName {
    final first = details.firstName.isNotEmpty
        ? details.firstName
        : status.firstName;
    final last = details.firstName.isNotEmpty
        ? details.lastName
        : status.lastName;
    return [first, last].where((p) => p.trim().isNotEmpty).join(' ');
  }

  String get initials => fullName
      .split(' ')
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();

  SavedAddress? get defaultAddress {
    for (final a in addresses) {
      if (a.isDefault) return a;
    }
    return addresses.isEmpty ? null : addresses.first;
  }

  /// "+1 (415) 555-0142 · San Francisco".
  String get contactLine => [
    details.displayPhone,
    defaultAddress?.city,
  ].whereType<String>().where((p) => p.isNotEmpty).join(' · ');

  bool get isLicenseVerified => status.isApproved;

  ProfileOverview copyWith({
    RideMode? rideMode,
    List<SavedAddress>? addresses,
  }) => ProfileOverview(
    status: status,
    rideMode: rideMode ?? this.rideMode,
    details: details,
    kids: kids,
    kidsError: kidsError,
    addresses: addresses ?? this.addresses,
    addressesError: addresses != null ? null : addressesError,
    rideGroups: rideGroups,
  );

  @override
  List<Object?> get props => [
    status,
    rideMode,
    details,
    kids.map((k) => k.id).toList(),
    kidsError,
    addresses,
    addressesError,
    rideGroups,
  ];
}
