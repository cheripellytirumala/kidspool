import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../entities/ride_ask.dart';
import '../entities/chat_person.dart';
import '../entities/ride_chat.dart';
import '../entities/ride_group.dart';
import '../entities/ride_request.dart';

/// Ride requests, offers and ride chats (Messages tab).
///
/// Chat calls fail with code `MessagesApiConstants.chatMissing` while the
/// chat SQL isn't applied on the server; ride group calls fail with
/// `MessagesApiConstants.groupsMissing` until the groups SQL is applied.
abstract interface class MessagesRepository {
  /// `profiles.id` of the signed-in user (tells own messages apart).
  String? get myUserId;

  bool get isSignedIn;

  // Requests
  Future<Either<Failure, RequestsInbox>> getRequestsInbox();

  /// Rides tab (F19c): the user's own requests and the rides they drive
  /// (booked only — pending offers live in Requests). [scope] is
  /// `upcoming` (soonest first) or `past` (newest first).
  Future<Either<Failure, List<RideRequest>>> getMyRides(String scope);

  /// The user's own request with its offers and driver.
  Future<Either<Failure, RideRequest>> getMyRequest(String requestId);

  /// A request the user drives / offered on / was sent (Ride Partner).
  Future<Either<Failure, RideRequest>> getDriveRequest(String requestId);

  Future<Either<Failure, RequestActivity>> getRequestActivity(String requestId);

  /// Returns the confirmed Ride Partner on approve.
  Future<Either<Failure, ChatPerson?>> respondToOffer(
    String offerId, {
    required bool approve,
  });

  Future<Either<Failure, Unit>> cancelRideRequest(String requestId);

  Future<Either<Failure, OfferOutcome>> offerRide(String requestId);

  Future<Either<Failure, Unit>> withdrawOffer(String offerId);

  Future<Either<Failure, Unit>> driverCancelRide(String requestId);

  /// "Not this time": hides the request on this device (no API).
  Future<Either<Failure, Unit>> passRequest(String requestId);

  // Chat
  Future<Either<Failure, List<RideChat>>> getMyChats();

  Future<Either<Failure, List<ChatMessage>>> getMessages({
    required String requestId,
    required String driverId,
  });

  Future<Either<Failure, ChatMessage>> sendMessage({
    required String requestId,
    required String driverId,
    required String body,
  });

  // Ride groups
  Future<Either<Failure, List<RideGroup>>> getMyGroups();

  Future<Either<Failure, RideGroupDetails>> getGroup(String groupId);

  /// Latest messages of a group, oldest first.
  Future<Either<Failure, List<GroupMessage>>> getGroupMessages(String groupId);

  Future<Either<Failure, GroupMessage>> sendGroupMessage({
    required String groupId,
    required String body,
  });

  Future<Either<Failure, Unit>> markGroupRead(String groupId);

  /// Starts a group with the user as owner. Returns its id.
  Future<Either<Failure, String>> createGroup({
    required String name,
    required List<String> memberIds,
    String? schoolId,
  });

  /// Returns how many parents were added.
  Future<Either<Failure, int>> addGroupMembers({
    required String groupId,
    required List<String> memberIds,
  });

  Future<Either<Failure, Unit>> leaveGroup(String groupId);

  Future<Either<Failure, Unit>> renameGroup({
    required String groupId,
    required String name,
  });

  Future<Either<Failure, Unit>> setGroupMuted({
    required String groupId,
    required bool muted,
  });

  /// Parents the user may add ([groupId] null: for a new group).
  Future<Either<Failure, List<RideGroupMember>>> getGroupCandidates(
    String? groupId,
  );

  // Ride asks (cards in group chats)

  Future<Either<Failure, GroupMessage>> postRideAsk({
    required String groupId,
    required List<Map<String, dynamic>> rides,
    required String summary,
  });

  Future<Either<Failure, List<RideAsk>>> getGroupRideAsks(String groupId);

  Future<Either<Failure, Unit>> helpWithRideAsk(String askId);
}
