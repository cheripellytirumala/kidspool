import 'package:equatable/equatable.dart';

/// Result of `request-otp`.
class OtpRequest extends Equatable {
  const OtpRequest({
    required this.expiresIn,
    required this.resendAfter,
    this.demoCode,
  });

  /// Seconds until the code expires.
  final int expiresIn;

  /// Seconds before another code can be requested.
  final int resendAfter;

  /// The code itself, only returned while the backend runs in demo mode
  /// (no SMS provider configured). Used to auto-fill the field.
  final String? demoCode;

  @override
  List<Object?> get props => [expiresIn, resendAfter, demoCode];
}

/// Home address saved with `add_address`.
class HomeAddress extends Equatable {
  const HomeAddress({
    required this.street,
    required this.city,
    required this.stateCode,
    required this.zip,
    required this.latitude,
    required this.longitude,
    this.apt = '',
    this.isDefault = true,
  });

  final String street;
  final String apt;
  final String city;
  final String stateCode;
  final String zip;
  final double latitude;
  final double longitude;
  final bool isDefault;

  @override
  List<Object?> get props => [
    street,
    apt,
    city,
    stateCode,
    zip,
    latitude,
    longitude,
    isDefault,
  ];
}

/// Photos and name sent to `submit-identity-verification`.
class IdentitySubmission extends Equatable {
  const IdentitySubmission({
    required this.firstName,
    required this.lastName,
    required this.idType,
    required this.selfiePath,
    required this.idFrontPath,
    this.idBackPath,
  });

  final String firstName;
  final String lastName;

  /// `id_document_types.code`, e.g. `drivers_license`.
  final String idType;

  /// Local file paths (JPEG/PNG, ≤ 1 MB each).
  final String selfiePath;
  final String idFrontPath;
  final String? idBackPath;

  @override
  List<Object?> get props => [
    firstName,
    lastName,
    idType,
    selfiePath,
    idFrontPath,
    idBackPath,
  ];
}
