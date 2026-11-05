import 'place.dart';

/// Turns what the parent typed in F09 into a Google Text Search query.
///
/// * empty → "schools" / "kids activities" (biased near home)
/// * zip code ("94110") → "schools in 94110"
/// * address or street ("Valencia St San Francisco") →
///   "schools near Valencia St San Francisco"
/// * anything else (a name: "Lincoln Elementary") → sent as typed
abstract final class PlaceSearchQuery {
  /// Google place type for the School tab (`includedType`).
  static const String schoolType = 'school';

  static String? includedType(PlaceKind kind) =>
      kind == PlaceKind.school ? schoolType : null;

  static String build(PlaceKind kind, String typed) {
    final q = typed.trim().replaceAll(RegExp(r'\s+'), ' ');
    final noun = kind == PlaceKind.school ? 'schools' : 'kids activities';
    if (q.isEmpty) return noun;
    if (isZipCode(q)) return '$noun in $q';
    if (kind == PlaceKind.school && _namesASchool(q)) return q;
    if (looksLikeAddress(q)) return '$noun near $q';
    return q;
  }

  static final RegExp _zip = RegExp(r'^\d{5}(-\d{4})?$');

  static bool isZipCode(String q) => _zip.hasMatch(q.trim());

  static final RegExp _schoolWords = RegExp(
    r'\b(school|schools|elementary|middle|high|academy|prep|preparatory|'
    r'montessori|preschool|pre-k|kindergarten|charter|daycare|'
    r'learning|institute|college)\b',
    caseSensitive: false,
  );

  static bool _namesASchool(String q) => _schoolWords.hasMatch(q);

  static final RegExp _streetWords = RegExp(
    r'\b(st|street|ave|avenue|blvd|boulevard|rd|road|dr|drive|ln|lane|way|'
    r'ct|court|pl|place|hwy|highway|pkwy|parkway|ter|terrace|sq|square|cir|'
    r'circle)\b\.?',
    caseSensitive: false,
  );

  /// Starts with a house number, has a comma, or names a street.
  static bool looksLikeAddress(String q) =>
      RegExp(r'^\d+\s').hasMatch(q) ||
      q.contains(',') ||
      _streetWords.hasMatch(q);
}
