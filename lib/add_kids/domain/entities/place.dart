/// Whether a place is a school or an after-school activity.
enum PlaceKind { school, activity }

/// Drives the place icon.
enum PlaceCategory {
  school,
  soccer,
  swim,
  music,
  dance,

  /// Any other activity (generic icon).
  activity;

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
    this.googlePlaceId,
    this.latitude,
    this.longitude,
    this.addressLine = '',
    this.city = '',
    this.state = '',
    this.zip = '',
  });

  /// `schools.id` for saved schools; the Google place id for search
  /// results and activities.
  final String id;
  final String name;
  final PlaceCategory category;

  /// e.g. "1200 Valencia St, San Francisco · 94110".
  final String details;

  /// Extra search terms (ZIP code, activity type).
  final String keywords;

  /// Set when the place comes from Google Places search.
  final String? googlePlaceId;
  final double? latitude;
  final double? longitude;
  final String addressLine;
  final String city;

  /// Two-letter state code, e.g. `CA`.
  final String state;
  final String zip;

  PlaceKind get kind => category.kind;

  /// A Google result that still needs a `schools.id` before saving.
  bool get isGooglePlace => googlePlaceId != null;

  Place copyWith({String? id}) => Place(
    id: id ?? this.id,
    name: name,
    category: category,
    details: details,
    keywords: keywords,
    googlePlaceId: googlePlaceId,
    latitude: latitude,
    longitude: longitude,
    addressLine: addressLine,
    city: city,
    state: state,
    zip: zip,
  );

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '$name $details $keywords ${category.name}'.toLowerCase().contains(
      q,
    );
  }
}
