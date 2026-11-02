/// A child of the signed-in parent (`kids` table, via `get_my_kids`).
class Child {
  const Child({
    required this.id,
    required this.firstName,
    this.lastName = '',
    this.dateOfBirth,
    this.age,
    this.grade,
    this.medicalNotes = '',
    this.photo,
    this.schoolId,
    this.schoolName,
    this.needsBooster = false,
    this.hasSchoolIdCard = false,
  });

  final String id;
  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;

  /// Age in years (from the server, or computed from [dateOfBirth]).
  final int? age;
  final String? grade;

  /// `health_notes`.
  final String medicalNotes;

  /// Image source: a signed `https://` URL, a local file path, or a bundled
  /// asset path. `null` = show initials.
  final String? photo;
  final String? schoolId;
  final String? schoolName;
  final bool needsBooster;
  final bool hasSchoolIdCard;

  String get initials {
    final letters = [firstName, lastName]
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part.trim()[0].toUpperCase());
    return letters.join();
  }

  int? get displayAge =>
      age ?? (dateOfBirth == null ? null : ageOn(dateOfBirth!));

  /// "8 years · Grade 3".
  String get summary {
    final years = displayAge;
    return [
      if (years != null) '$years ${years == 1 ? 'year' : 'years'}',
      ?grade,
    ].join(' · ');
  }

  static int ageOn(DateTime birth, [DateTime? today]) {
    final now = today ?? DateTime.now();
    var years = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      years--;
    }
    return years;
  }
}

/// Form values sent to `add-kid` / `update-kid`.
class ChildDraft {
  const ChildDraft({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.grade,
    required this.schoolId,
    required this.medicalNotes,
    required this.needsBooster,
    this.newPhotoPath,
    this.newSchoolIdCardPath,
  });

  /// `null` → create, otherwise update.
  final String? id;
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final String? grade;
  final String schoolId;
  final String medicalNotes;
  final bool needsBooster;

  /// Local files picked in this session (only uploaded when set).
  final String? newPhotoPath;
  final String? newSchoolIdCardPath;
}
