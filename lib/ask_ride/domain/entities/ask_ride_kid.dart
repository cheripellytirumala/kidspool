import 'package:equatable/equatable.dart';

/// A child the parent can ask a ride for.
class AskRideKid extends Equatable {
  const AskRideKid({
    required this.id,
    required this.name,
    this.photo,
    this.schoolId,
    this.schoolName,
    this.needsBooster = false,
  });

  final String id;
  final String name;

  /// Signed photo URL or bundled asset path; `null` shows initials.
  final String? photo;

  /// Rides go to this school (the backend derives the drop-off from it).
  final String? schoolId;
  final String? schoolName;
  final bool needsBooster;

  String get initial => name.isEmpty ? '?' : name[0].toUpperCase();

  @override
  List<Object?> get props => [id, name, photo, schoolId, needsBooster];
}
