import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../entities/chat_person.dart';
import '../entities/ride_chat.dart';
import '../entities/ride_request.dart';

/// Ride requests, offers and ride chats (Messages tab).
///
/// Chat calls fail with code `MessagesApiConstants.chatMissing` while the
/// chat SQL isn't applied on the server.
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
}
