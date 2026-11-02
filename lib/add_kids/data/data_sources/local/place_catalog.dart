import '../../../domain/entities/place.dart';

/// Local list of after-school activities. Schools come from the
/// `get_schools` RPC; the backend has no activities table yet.
class PlaceCatalog {
  const PlaceCatalog();

  static const List<Place> places = [
    Place(
      id: 'westside-soccer',
      name: 'Westside Soccer Club',
      category: PlaceCategory.soccer,
      details: 'Kezar Field',
      keywords: 'soccer football 94117',
    ),
    Place(
      id: 'harmony-music',
      name: 'Harmony Music Academy',
      category: PlaceCategory.music,
      details: '455 Valencia St',
      keywords: 'music piano guitar 94103',
    ),
    Place(
      id: 'mission-swim',
      name: 'Mission Swim Center',
      category: PlaceCategory.swim,
      details: '1 Linda St',
      keywords: 'swim pool 94110',
    ),
    Place(
      id: 'bay-dance',
      name: 'Bay Dance Studio',
      category: PlaceCategory.dance,
      details: '2148 Mission St',
      keywords: 'dance ballet 94110',
    ),
  ];

  Place? byId(String id) {
    for (final place in places) {
      if (place.id == id) return place;
    }
    return null;
  }

  List<Place> search(PlaceKind kind, String query) => [
    for (final place in places)
      if (place.kind == kind && place.matches(query)) place,
  ];
}
