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
  static const String allSet = '/kids/all-set';

  // Home
  static const String home = '/home';
  static const String familiesNearYou = '/home/families';

  // F25b · Notifications (Home bell)
  static const String notifications = '/notifications';

  // Ask for a ride
  static const String askRide = '/ask-ride';
  static const String messageSent = '/ask-ride/sent';

  // Rides tab (F19c · Your rides)
  static const String rides = '/rides';

  // Profile
  static const String profile = '/profile';

  // Messages (F24 / F24a). Chat + group info take [RideChatArgs]; the
  // request detail (A7a) takes `RideRequestArgs` from lib/messages.
  static const String messages = '/messages';
  static const String rideRequestDetail = '/messages/request';
  static const String rideChat = '/messages/chat';
  static const String rideGroupInfo = '/messages/group';

  // Ride groups (standing groups of families). Both take [GroupChatArgs].
  static const String groupChat = '/messages/groups/chat';
  static const String groupInfo = '/messages/groups/info';

  // Ride day (arguments: [RideArgs])
  static const String liveTracking = '/ride/live';
  static const String rideCompleted = '/ride/completed';

  // In-app web page (arguments: [WebPageArgs])
  static const String webPage = '/web';
}

/// Route arguments for the in-app web page (Terms, Privacy Policy).
class WebPageArgs {
  const WebPageArgs({required this.title, required this.url});

  final String title;
  final String url;
}

/// Route arguments for ride-day screens.
class RideArgs {
  const RideArgs(this.requestId);

  /// `ride_requests.id` of the booked ride.
  final String requestId;
}

/// Route arguments for a ride chat (F19) and its group info (GC6). A chat is
/// the pair (ride request, Ride Partner).
class RideChatArgs {
  const RideChatArgs({
    required this.requestId,
    required this.driverId,
    required this.iAmDriver,
    this.otherName,
    this.otherInitials,
  });

  /// `ride_requests.id`.
  final String requestId;

  /// `profiles.id` of the Ride Partner in this chat.
  final String driverId;

  /// The signed-in user is the Ride Partner (else the requesting parent).
  final bool iAmDriver;

  /// The other parent's first name / initials, shown before the ride loads.
  final String? otherName;
  final String? otherInitials;
}

/// Route arguments for a ride group's chat and its info screen.
class GroupChatArgs {
  const GroupChatArgs({required this.groupId, this.name});

  /// `ride_groups.id`.
  final String groupId;

  /// The group's name, shown before the group loads.
  final String? name;
}
