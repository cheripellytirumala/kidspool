/// Short description of the ride the user just asked for.
class RideSummary {
  const RideSummary({
    required this.childName,
    this.childPhoto,
    required this.from,
    required this.to,
    required this.schedule,
  });

  final String childName;

  /// Bundled asset path or signed photo URL; `null` shows initials.
  final String? childPhoto;
  final String from;
  final String to;

  /// e.g. "Tue & Thu 8:30 AM · weekly · return 3:30 PM".
  final String schedule;

  /// "Emma · Home → Lincoln"
  String get title => '$childName · $from → $to';

  String get childInitial =>
      childName.isEmpty ? '?' : childName[0].toUpperCase();
}
