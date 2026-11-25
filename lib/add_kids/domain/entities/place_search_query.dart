import 'place.dart';

/// Turns what the parent typed in F09 into a Google Text Search query.
///
/// * empty → "schools" suggestions (biased near home)
/// * zip code ("94110") → "schools in 94110"
/// * anything else (a name or an address) → sent as typed, any place type
abstract final class PlaceSearchQuery {
  /// Google place type for the suggestions shown before anything is typed.
  static const String schoolType = 'school';

  /// "Add location": suggestions are nearby schools, but anything typed
  /// finds any place (an office, a club, a relative's home).
  static String? includedType(PlaceKind kind, [String typed = '']) =>
      kind == PlaceKind.school && typed.trim().isEmpty ? schoolType : null;

  static String build(PlaceKind kind, String typed) {
    final q = typed.trim().replaceAll(RegExp(r'\s+'), ' ');
    final noun = kind == PlaceKind.school ? 'schools' : 'kids activities';
    if (q.isEmpty) return noun;
    if (isZipCode(q)) return '$noun in $q';
    // A location: search what was typed (a name or an address).
    if (kind == PlaceKind.school) return q;
    if (looksLikeAddress(q)) return '$noun near $q';
    return q;
  }

  static final RegExp _zip = RegExp(r'^\d{5}(-\d{4})?$');

  static bool isZipCode(String q) => _zip.hasMatch(q.trim());

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
