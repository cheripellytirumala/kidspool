/// One of a [Family]'s kids and the school they share with the user's kids.
class FamilyKid {
  const FamilyKid({
    required this.firstName,
    required this.schoolId,
    required this.schoolName,
  });

  final String firstName;

  /// Null when the kid only shares an activity with the user's kids.
  final String? schoolId;
  final String schoolName;
}

/// An activity (Funland, swim club…) a family's kids share with the
/// user's kids. [id] is `activity:<place key>`.
typedef FamilyActivity = ({String id, String name});

/// A nearby family whose kids go to the same schools as the user's kids
/// (`get_families_near_me`). No photo: the avatar shows [initials].
class Family {
  const Family({
    required this.id,
    required this.parentName,
    required this.initials,
    required this.kids,
    this.distanceMiles,
    this.givesRides = false,
    this.activities = const [],
  });

  /// Activities shared with the user's kids.
  final List<FamilyActivity> activities;

  final String id;

  /// e.g. "Jen P."
  final String parentName;

  /// e.g. "JP" — shown in the avatar.
  final String initials;

  /// Kids that share a school with the user's kids.
  final List<FamilyKid> kids;

  /// Rounded to 0.1 mi; null when either home has no location.
  final double? distanceMiles;

  /// Approved driver: can give rides.
  final bool givesRides;

  /// No driver approval: the family is looking for rides.
  bool get needsRides => !givesRides;

  /// Ids of the schools and activities this family shares with the user.
  Set<String> get placeIds => {
    for (final k in kids) ?k.schoolId,
    for (final a in activities) a.id,
  };

  /// School names (then shared activities) in kid order, no duplicates.
  List<String> get schoolNames => {
    for (final k in kids)
      if (k.schoolName.isNotEmpty) k.schoolName,
    for (final a in activities) a.name,
  }.toList(growable: false);

  /// "Mia", "Mia & Leo", "Mia, Leo & Ava".
  String get childLabel {
    final names = {
      for (final k in kids)
        if (k.firstName.isNotEmpty) k.firstName,
    }.toList();
    if (names.length <= 1) return names.firstOrNull ?? '';
    return '${names.sublist(0, names.length - 1).join(', ')} & ${names.last}';
  }

  /// e.g. "Lincoln Elementary" (or "Lincoln Elementary, Oak Middle").
  String get placeName => schoolNames.join(', ');

  /// e.g. "Lincoln" — used on compact cards.
  String get shortPlaceName => shortSchoolName(schoolNames.firstOrNull ?? '');

  /// "0.4 mi"; null when the distance is unknown.
  String? get distanceLabel {
    final miles = distanceMiles;
    if (miles == null) return null;
    return '${miles.toStringAsFixed(1)} mi';
  }

  /// "Mia · Lincoln Elementary · 0.4 mi"
  String get detailLabel =>
      [childLabel, placeName, distanceLabel ?? ''].where(_present).join(' · ');

  /// "Lincoln · 0.4 mi"
  String get compactLabel =>
      [shortPlaceName, distanceLabel ?? ''].where(_present).join(' · ');

  static bool _present(String s) => s.isNotEmpty;

  static const _schoolWords = {
    'elementary',
    'middle',
    'high',
    'school',
    'academy',
    'primary',
    'secondary',
  };

  /// "Lincoln Elementary School" → "Lincoln"; keeps the name when every
  /// word is generic.
  static String shortSchoolName(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    while (words.length > 1 &&
        _schoolWords.contains(words.last.toLowerCase())) {
      words.removeLast();
    }
    return words.join(' ');
  }
}

/// Result of `get_families_near_me`.
class FamiliesNearMe {
  const FamiliesNearMe({required this.families, required this.hasSchool});

  /// Nearest first.
  final List<Family> families;

  /// False when none of the user's kids has a school yet (the list is then
  /// always empty).
  final bool hasSchool;
}
