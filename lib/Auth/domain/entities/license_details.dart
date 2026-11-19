import 'package:equatable/equatable.dart';

/// Where the license details were read from.
enum LicenseReadSource {
  /// PDF417 barcode on the back (AAMVA data): most reliable.
  barcode,

  /// Text recognition on the front photo: best effort.
  text,
}

/// Details read on the device (Google ML Kit) from the license photos.
/// Shown on V3 so the parent can check them; never sent to the backend —
/// the reviewer checks the photos themselves.
class LicenseDetails extends Equatable {
  const LicenseDetails({
    required this.source,
    this.firstName,
    this.lastName,
    this.licenseNumber,
    this.expiryDate,
    this.birthDate,
    this.state,
    this.city,
  });

  final LicenseReadSource source;
  final String? firstName;
  final String? lastName;
  final String? licenseNumber;
  final DateTime? expiryDate;
  final DateTime? birthDate;

  /// Two-letter state code, e.g. `CA`.
  final String? state;
  final String? city;

  bool get isEmpty =>
      fullName.isEmpty &&
      licenseNumber == null &&
      expiryDate == null &&
      birthDate == null;

  String get fullName => [
    firstName,
    lastName,
  ].whereType<String>().where((p) => p.trim().isNotEmpty).join(' ');

  bool get isExpired {
    final expiry = expiryDate;
    if (expiry == null) return false;
    final now = DateTime.now();
    return expiry.isBefore(DateTime(now.year, now.month, now.day));
  }

  /// Age in whole years from [birthDate], or null when it wasn't read.
  int? ageOn([DateTime? today]) {
    final birth = birthDate;
    if (birth == null) return null;
    final now = today ?? DateTime.now();
    var years = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      years--;
    }
    return years;
  }

  /// Drivers must be adults: true when the birth date says under 18.
  bool get isUnder18 => (ageOn() ?? 18) < 18;

  /// "D•••482" — only the last 3 characters are shown.
  String? get maskedNumber {
    final n = licenseNumber;
    if (n == null || n.length < 4) return n;
    return '${n[0]}•••${n.substring(n.length - 3)}';
  }

  @override
  List<Object?> get props => [
    source,
    firstName,
    lastName,
    licenseNumber,
    expiryDate,
    birthDate,
    state,
    city,
  ];
}
