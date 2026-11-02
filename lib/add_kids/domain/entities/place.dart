/// Whether a place is a school or an after-school activity.
enum PlaceKind { school, activity }

/// Drives the place icon.
enum PlaceCategory {
  school,
  soccer,
  swim,
  music,
  dance;

  PlaceKind get kind =>
      this == PlaceCategory.school ? PlaceKind.school : PlaceKind.activity;
}

/// A school or activity kids go to (F09).
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.category,
    this.details = '',
    this.keywords = '',
  });

  final String id;
  final String name;
  final PlaceCategory category;

  /// e.g. "Public · K–5 · 1200 Valencia St · 94110".
  final String details;

  /// Extra search terms (ZIP code, activity type).
  final String keywords;

  PlaceKind get kind => category.kind;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '$name $details $keywords ${category.name}'.toLowerCase().contains(
      q,
    );
  }
}
