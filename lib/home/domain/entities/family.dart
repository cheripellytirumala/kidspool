/// A nearby family whose kids go to the same places as the user's kids.
class Family {
  const Family({
    required this.id,
    required this.parentName,
    required this.childLabel,
    required this.placeName,
    required this.shortPlaceName,
    required this.distanceMiles,
    required this.avatarAsset,
    required this.placeIds,
    this.givesRides = false,
    this.needsRides = false,
  });

  final String id;

  /// e.g. "Jen P."
  final String parentName;

  /// e.g. "Mia" or "Grandson Jack".
  final String childLabel;

  /// e.g. "Lincoln Elementary".
  final String placeName;

  /// e.g. "Lincoln" — used on compact cards.
  final String shortPlaceName;
  final double distanceMiles;
  final String avatarAsset;

  /// Ids of the [KidPlace]s this family shares with the user.
  final Set<String> placeIds;
  final bool givesRides;
  final bool needsRides;

  String get distanceLabel => '$distanceMiles mi';

  /// "Mia · Lincoln Elementary · 0.4 mi"
  String get detailLabel => '$childLabel · $placeName · $distanceLabel';

  /// "Lincoln · 0.4 mi"
  String get compactLabel => '$shortPlaceName · $distanceLabel';
}
