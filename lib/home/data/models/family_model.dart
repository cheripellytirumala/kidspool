import '../../../common/core/utils/json_parser.dart';
import '../../domain/entities/family.dart';

/// Maps a `get_families_near_me` row:
/// `{id, firstName, lastInitial, initials, givesRides,
/// kids: [{firstName, schoolId, schoolName}], distanceMiles}`.
abstract final class FamilyModel {
  /// Null when the row has no id.
  static Family? fromJson(Map<String, dynamic> json) {
    final id = json.readString('id');
    if (id == null || id.isEmpty) return null;
    final first = (json.readString('firstName') ?? '').trim();
    final lastInitial = (json.readString('lastInitial') ?? '').trim();
    final name = lastInitial.isEmpty
        ? first
        : '$first ${lastInitial[0].toUpperCase()}.'.trim();
    final initials = (json.readString('initials') ?? '').trim();
    final distance = json['distanceMiles'];
    return Family(
      id: id,
      parentName: name.isEmpty ? 'A parent' : name,
      initials: initials.isNotEmpty
          ? initials.toUpperCase()
          : _initials(first, lastInitial),
      kids: json
          .readList('kids', _kid)
          .whereType<FamilyKid>()
          .toList(growable: false),
      distanceMiles: distance is num
          ? distance.toDouble()
          : double.tryParse(distance?.toString() ?? ''),
      givesRides: json['givesRides'] == true,
    );
  }

  static FamilyKid? _kid(Map<String, dynamic> json) {
    final schoolId = json.readString('schoolId');
    if (schoolId == null || schoolId.isEmpty) return null;
    return FamilyKid(
      firstName: (json.readString('firstName') ?? '').trim(),
      schoolId: schoolId,
      schoolName: (json.readString('schoolName') ?? '').trim(),
    );
  }

  static String _initials(String first, String lastInitial) =>
      '${first.isEmpty ? '' : first[0]}'
              '${lastInitial.isEmpty ? '' : lastInitial[0]}'
          .toUpperCase();
}
