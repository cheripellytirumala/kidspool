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
    this.age,
  });

  /// US guidance: kids ride in a booster seat until about age 8 (and
  /// 4 ft 9 in tall).
  static const int boosterUntilAge = 8;

  final String id;
  final String name;

  /// Signed photo URL or bundled asset path; `null` shows initials.
  final String? photo;

  /// Rides go to this school (the backend derives the drop-off from it).
  final String? schoolId;
  final String? schoolName;

  /// Set on the child's profile ("Needs a booster seat").
  final bool needsBooster;

  /// Years, from the date of birth; null when unknown.
  final int? age;

  /// Too young to ride without a booster seat.
  bool get youngForBooster => age != null && age! < boosterUntilAge;

  /// The ride should ask for a booster seat for this child.
  bool get boosterSuggested => needsBooster || youngForBooster;

  String get initial => name.isEmpty ? '?' : name[0].toUpperCase();

  @override
  List<Object?> get props => [id, name, photo, schoolId, needsBooster, age];
}
