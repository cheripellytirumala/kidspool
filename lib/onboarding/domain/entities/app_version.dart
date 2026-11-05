import 'package:equatable/equatable.dart';

/// Result of the launch-time version check (`check_app_version`).
///
/// Pure domain object: strongly typed, no JSON knowledge.
class AppVersion extends Equatable {
  const AppVersion({
    required this.isUpdateRequired,
    required this.minSupportedVersion,
    required this.storeUrl,
    required this.message,
  });

  /// True when the running build is older than [minSupportedVersion].
  final bool isUpdateRequired;
  final String minSupportedVersion;
  final String storeUrl;
  final String message;

  @override
  List<Object?> get props => [
    isUpdateRequired,
    minSupportedVersion,
    storeUrl,
    message,
  ];
}
