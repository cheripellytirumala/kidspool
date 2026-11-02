/// Route names for the "Easy flow" (S01 → F20).
abstract final class AppRoutes {
  static const String splash = '/';

  // Auth
  static const String phoneNumber = '/auth/phone';
  static const String otp = '/auth/otp';
  static const String aboutYou = '/auth/about-you';
  static const String scanPhotoId = '/auth/scan-id';
  static const String idVerified = '/auth/id-verified';
  static const String reviewPending = '/auth/review-pending';

  // Kids
  static const String addChild = '/kids/add';
  static const String yourKids = '/kids';
  static const String whereKidsGo = '/kids/places';
  static const String findSchool = '/kids/find-school';
  static const String whoGoesWhen = '/kids/schedule';
  static const String childPlaces = '/kids/child-places';
  static const String allSet = '/kids/all-set';

  // Home
  static const String home = '/home';
  static const String familiesNearYou = '/home/families';

  // Ask for a ride
  static const String askRide = '/ask-ride';
  static const String messageSent = '/ask-ride/sent';

  // Profile
  static const String profile = '/profile';

  // Ride day (arguments: [RideArgs])
  static const String liveTracking = '/ride/live';
  static const String rideCompleted = '/ride/completed';
}

/// Route arguments for ride-day screens.
class RideArgs {
  const RideArgs(this.requestId);

  /// `ride_requests.id` of the booked ride.
  final String requestId;
}
