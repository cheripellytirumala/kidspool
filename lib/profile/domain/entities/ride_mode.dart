/// How the parent uses KidPool ("I want to" on About you). Stored on the
/// device under `AppConstants.cacheKeyRideRole` (`seeker` / `both`).
enum RideMode {
  /// "I need rides" — only asks for rides.
  seeker,

  /// "I get & give rides" — asks for rides and offers seats.
  both;

  static RideMode parse(String? value) => value == seeker.name ? seeker : both;

  String get title => switch (this) {
    seeker => 'I get rides only',
    both => 'I get & give rides',
  };

  String get description => switch (this) {
    seeker => 'Ask families at your kids’ schools and clubs',
    both => 'Ask for rides and help other families',
  };
}
