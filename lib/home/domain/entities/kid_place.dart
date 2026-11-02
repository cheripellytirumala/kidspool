/// Kind of place a kid goes to; drives the chip icon.
enum KidPlaceKind { school, activity }

/// A place the user's kids go to (school, club…), used to group families.
class KidPlace {
  const KidPlace({required this.id, required this.name, required this.kind});

  final String id;
  final String name;
  final KidPlaceKind kind;
}
