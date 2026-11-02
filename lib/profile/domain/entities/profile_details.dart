import 'package:equatable/equatable.dart';

/// Contact details of the signed-in parent (`profiles` row).
class ProfileDetails extends Equatable {
  const ProfileDetails({this.firstName = '', this.lastName = '', this.phone});

  /// Legal name from the photo ID (falls back to the sign-up name).
  final String firstName;
  final String lastName;

  /// E.164, e.g. `+14155550142`.
  final String? phone;

  /// "+1 (415) 555-0142" for US numbers, otherwise the raw value.
  String? get displayPhone {
    final raw = phone?.trim();
    if (raw == null || raw.isEmpty) return null;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final national = switch (digits.length) {
      11 when digits.startsWith('1') => digits.substring(1),
      10 => digits,
      _ => null,
    };
    if (national == null) return raw;
    return '+1 (${national.substring(0, 3)}) '
        '${national.substring(3, 6)}-${national.substring(6)}';
  }

  @override
  List<Object?> get props => [firstName, lastName, phone];
}
