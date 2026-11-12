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

  /// `pass_ride_request(requestId)` — "Not this time", saved on the server
  /// (`docs/backend/2026-11-10_pass_ride_request.sql`).
  static const String passRideRequest = 'pass_ride_request';

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

  // -------------------------------------------------------- ride groups
  // `docs/backend/2026-11-09_ride_groups.sql`; may not be on the server yet:
  // see [groupsMissing].

  /// `get_my_ride_groups()` → `[{id, name, memberCount, unread, muted,
  /// lastMessage, lastAt}]`, newest first.
  static const String getMyRideGroups = 'get_my_ride_groups';

  /// `get_ride_group(groupId)` → `{id, name, schoolName, muted, maxMembers,
  /// members: [{id, firstName, initials, role, isMe, kids}]}`.
  static const String getRideGroup = 'get_ride_group';

  /// `get_ride_group_messages(groupId, before?)` → `[{id, kind, body,
  /// createdAt, sender{id, firstName, initials} | null}]`, oldest first.
  static const String getRideGroupMessages = 'get_ride_group_messages';

  /// `send_ride_group_message(groupId, body)` → the message.
  static const String sendRideGroupMessage = 'send_ride_group_message';

  /// Ride asks in groups (`docs/backend/2026-11-11_group_ride_asks.sql`):
  /// the request is created only when a driver taps "I can help".
  static const String postRideAsk = 'post_ride_ask';
  static const String getGroupRideAsks = 'get_group_ride_asks';
  static const String helpWithRideAsk = 'help_with_ride_ask';

  /// Client code: the ride-ask SQL isn't on the server yet.
  static const String rideAsksMissing = 'ride_asks_not_deployed';

  /// `mark_ride_group_read(groupId)`.
  static const String markRideGroupRead = 'mark_ride_group_read';

  /// `create_ride_group(name, memberIds, schoolId?)` → `{id}`.
  static const String createRideGroup = 'create_ride_group';

  /// `add_ride_group_members(groupId, memberIds)` → `{added}`.
  static const String addRideGroupMembers = 'add_ride_group_members';

  /// `leave_ride_group(groupId)`.
  static const String leaveRideGroup = 'leave_ride_group';

  /// `rename_ride_group(groupId, name)`.
  static const String renameRideGroup = 'rename_ride_group';

  /// `set_ride_group_muted(groupId, muted)`.
  static const String setRideGroupMuted = 'set_ride_group_muted';

  /// `get_ride_group_candidates(groupId?)` → `[{id, firstName, initials,
  /// kids}]` (parents the user may add; current members excluded).
  static const String getRideGroupCandidates = 'get_ride_group_candidates';

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

  /// App-side code of a `ServerException` raised when the ride group RPCs
  /// are not on the server yet.
  static const String groupsMissing = 'groups_not_deployed';

  /// Shown on a group screen while [groupsMissing]; lists stay quiet.
  static const String groupsMissingMessage = 'Group chats aren’t set up yet.';

  /// Families per ride group (`ride_group_max_members()`).
  static const int maxGroupMembers = 8;

  /// Group name limit (SQL check: 1–60 characters).
  static const int maxGroupNameLength = 60;

  /// `send_ride_message` body limit (SQL check).
  static const int maxMessageLength = 2000;

  /// Open-thread refresh while visible (no realtime client in this app).
  static const Duration threadPollInterval = Duration(seconds: 5);

  /// Private bucket of kid photos (`kids[].photoPath`).
  static const String kidPhotosBucket = 'kid-photos';
  static const int signedUrlSeconds = 3600;
}
