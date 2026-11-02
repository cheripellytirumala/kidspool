import 'package:equatable/equatable.dart';

enum PlaceKind { home, school }

/// A place the family saved earlier (home, school, activity).
class SavedPlace extends Equatable {
  const SavedPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.kind,
    this.detail,
  });

  /// e.g. `Home · 24 Maple St`, `Lincoln Elementary`.
  final String name;
  final String id;
  final String address;
  final PlaceKind kind;

  /// Extra context shown under the address, e.g. `school starts 9:00 AM`.
  final String? detail;

  @override
  List<Object?> get props => [id, name, address, kind, detail];
}
