/// Supabase RPCs used by the Messages group (F24 / F24a / A7a / F19 / GC6).
///
/// Ride RPCs are live (ported from the previous KidPool app). The chat RPCs
/// come from `docs/backend/2026-11-03_ride_messages.sql` and may not be on
/// the server yet: see [chatMissing].
abstract final class MessagesApiConstants {
  // ------------------------------------------------------- parent side

  /// `get_my_ride_requests(scope)` → `[ride_request_json]`.
  static const String getMyRideRequests = 'get_my_ride_requests';

  /// `get_ride_request(requestId)` → `ride_request_json + {driver, offers}`.
  static const String getRideRequest = 'get_ride_request';

  /// `get_request_activity(requestId)` → `{status, notifiedCount, seenCount,
  /// offersCount, notifiedDrivers, driverCancelledAt, driver}`.
  static const String getRequestActivity = 'get_request_activity';

  /// `respond_to_offer(offerId, action: approve|decline)`.
  static const String respondToOffer = 'respond_to_offer';

  /// `cancel_ride_request(requestId, scope: this)`.
  static const String cancelRideRequest = 'cancel_ride_request';

  // ------------------------------------------------- Ride Partner side

  /// `get_open_requests()` → `[driver_request_json + {isNew,
  /// openDaysInSeries, youAreBusy, myOffer}]`.
  static const String getOpenRequests = 'get_open_requests';

  /// `offer_ride(requestId, scope)` → `{groupId, status: confirmed |
  /// waiting_for_parent, offers: [{offerId, requestId, status}]}`.
  static const String offerRide = 'offer_ride';

  /// `withdraw_offer(offerId, scope)`.
  static const String withdrawOffer = 'withdraw_offer';

  /// `get_my_drives(scope)` → `{drives: [...], pendingOffers: [...]}`.
  static const String getMyDrives = 'get_my_drives';

  /// `driver_cancel_ride(requestId, scope)`.
  static const String driverCancelRide = 'driver_cancel_ride';

  // --------------------------------------------------------------- chat

  /// `get_my_ride_chats()` → `[{requestId, driverId, iAmDriver, status,
  /// other{id, firstName, initials}, lastMessage, lastAt, unread}]`.
  static const String getMyRideChats = 'get_my_ride_chats';

  /// `get_ride_messages(requestId, driverId)` → `[{id, senderId, body,
  /// createdAt, readAt}]`, oldest first.
  static const String getRideMessages = 'get_ride_messages';

  /// `send_ride_message(requestId, driverId, body)` → `{id, senderId, body,
  /// createdAt}`.
  static const String sendRideMessage = 'send_ride_message';

  // ------------------------------------------------------------- values

  static const String scopeUpcoming = 'upcoming';
  static const String scopePast = 'past';
  static const String scopeThis = 'this';
  static const String actionApprove = 'approve';
  static const String actionDecline = 'decline';

  /// PostgREST code for an RPC that isn't deployed.
  static const String functionNotFound = 'PGRST202';

  /// App-side code of a `ServerException` raised when the chat RPCs are not
  /// on the server yet.
  static const String chatMissing = 'chat_not_deployed';

  /// Shown in the composer / Chats tab while [chatMissing].
  static const String chatMissingMessage =
      'Chat isn’t set up on the server yet.';

  /// `send_ride_message` body limit (SQL check).
  static const int maxMessageLength = 2000;

  /// Open-thread refresh while visible (no realtime client in this app).
  static const Duration threadPollInterval = Duration(seconds: 5);

  /// Private bucket of kid photos (`kids[].photoPath`).
  static const String kidPhotosBucket = 'kid-photos';
  static const int signedUrlSeconds = 3600;
}
