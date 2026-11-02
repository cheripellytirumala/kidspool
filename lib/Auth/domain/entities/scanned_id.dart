import 'package:equatable/equatable.dart';

/// How the photo of the driver's license was obtained.
enum IdSource { camera, gallery }

/// The license photos captured on V1, shown for review on V3 before they
/// are sent to `submit-identity-verification`.
class ScannedId extends Equatable {
  const ScannedId({
    required this.source,
    required this.fullName,
    required this.location,
    required this.frontPath,
    this.backPath,
    this.selfiePath,
  });

  final IdSource source;

  /// Name typed on S04 (the reviewer checks it against the photo).
  final String fullName;
  final String location;

  /// Local photo files.
  final String frontPath;
  final String? backPath;
  final String? selfiePath;

  @override
  List<Object?> get props => [
    source,
    fullName,
    location,
    frontPath,
    backPath,
    selfiePath,
  ];
}
