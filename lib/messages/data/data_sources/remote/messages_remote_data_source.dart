import '../../../../common/core/constants/api_constants.dart';
import '../../../../common/core/error/exceptions.dart';
import '../../../../common/core/network/api_client.dart';
import '../../../../common/core/network/api_error_messages.dart';
import '../../../../common/core/utils/json_parser.dart';
import '../../../core/constants/messages_api_constants.dart';
import '../../../domain/entities/chat_person.dart';
import '../../../domain/entities/ride_chat.dart';
import '../../../domain/entities/ride_ask.dart';
import '../../../domain/entities/ride_group.dart';
import '../../../domain/entities/ride_request.dart';
import '../../models/ride_chat_model.dart';
import '../../models/ride_group_model.dart';
import '../../models/ride_request_model.dart';

/// Ride + chat RPCs of the Messages tab. Throws only `AppException`s.
///
/// Chat calls throw a [ServerException] with code
/// [MessagesApiConstants.chatMissing] when the chat RPCs are not deployed;
/// ride group calls likewise use [MessagesApiConstants.groupsMissing].
abstract interface class MessagesRemoteDataSource {
  /// `get_my_ride_requests(upcoming)`, open ones only.
  Future<List<RideRequest>> getMyOpenRequests();

  /// `get_my_ride_requests(scope)` — every status in that scope.
  Future<List<RideRequest>> getMyRequests(String scope);

  /// `get_ride_request(requestId)` (with offers and driver).
  Future<RideRequest> getMyRequest(String requestId);

  Future<RequestActivity> getRequestActivity(String requestId);

  /// `get_open_requests()`; empty when the user isn't a Ride Partner.
  Future<List<RideRequest>> getOpenRequests();

  /// `get_my_drives(scope)` → drives and pending offers.
  Future<List<RideRequest>> getMyDrives(String scope);

  Future<ChatPerson?> respondToOffer(String offerId, {required bool approve});

  Future<void> cancelRideRequest(String requestId);

  Future<OfferOutcome> offerRide(String requestId);

  Future<void> withdrawOffer(String offerId);

  Future<void> driverCancelRide(String requestId);

  /// "Not this time": `pass_ride_request` hides the request from
  /// `get_open_requests` for this driver. Does nothing until
  /// `docs/backend/2026-11-10_pass_ride_request.sql` is applied.
  Future<void> passRequest(String requestId);

  Future<List<RideChat>> getMyChats();

  Future<List<ChatMessage>> getMessages(String requestId, String driverId);

  Future<ChatMessage> sendMessage(
    String requestId,
    String driverId,
    String body,
  );

  // Ride groups
  Future<List<RideGroup>> getMyGroups();

  Future<RideGroupDetails> getGroup(String groupId);

  Future<List<GroupMessage>> getGroupMessages(String groupId);

  Future<GroupMessage> sendGroupMessage(String groupId, String body);

  /// Posts a ride ask card ([rides]: create_ride_request arguments, one
  /// per day). Throws [MessagesApiConstants.rideAsksMissing] when the SQL
  /// isn't applied.
  Future<GroupMessage> postRideAsk(
    String groupId,
    List<Map<String, dynamic>> rides,
    String summary,
  );

  Future<List<RideAsk>> getGroupRideAsks(String groupId);

  /// "I can help": creates the request for the parent with this offer.
  Future<void> helpWithRideAsk(String askId);

  Future<void> markGroupRead(String groupId);

  /// Returns the new group's id.
  Future<String> createGroup({
    required String name,
    required List<String> memberIds,
    String? schoolId,
  });

  /// Returns how many parents were added.
  Future<int> addGroupMembers(String groupId, List<String> memberIds);

  Future<void> leaveGroup(String groupId);

  Future<void> renameGroup(String groupId, String name);

  Future<void> setGroupMuted(String groupId, {required bool muted});

  Future<List<RideGroupMember>> getGroupCandidates(String? groupId);

  /// Signed URLs for private kid photo paths (failures → empty).
  Future<Map<String, String>> signKidPhotos(List<String> paths);
}

class MessagesRemoteDataSourceImpl implements MessagesRemoteDataSource {
  MessagesRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  final Map<String, String> _photoUrls = {};
  DateTime? _photosSignedAt;

  /// Codes meaning the user simply isn't a Ride Partner (yet).
  static const Set<String> notAPartnerCodes = {
    'not_a_driver',
    'address_required',
    'profile_not_found',
  };

  // ----------------------------------------------------------- parent

  @override
  Future<List<RideRequest>> getMyOpenRequests() async => (await getMyRequests(
    MessagesApiConstants.scopeUpcoming,
  )).where((r) => r.isOpen).toList(growable: false);

  @override
  Future<List<RideRequest>> getMyRequests(String scope) => _call(
    MessagesApiConstants.getMyRideRequests,
    {'scope': scope},
    'We couldn’t load your ride requests. Pull to refresh.',
    (json) {
      if (json is! List) throw const ParsingException();
      return [
        for (final row in json.whereType<Map>())
          ?RideRequestModel.mine(Map<String, dynamic>.from(row)),
      ];
    },
  );

  @override
  Future<RideRequest> getMyRequest(String requestId) => _call(
    MessagesApiConstants.getRideRequest,
    {'requestId': requestId},
    'We couldn’t load this ride. Pull to refresh.',
    (json) {
      final request = json is Map
          ? RideRequestModel.mine(Map<String, dynamic>.from(json))
          : null;
      if (request == null) throw const ParsingException();
      return request;
    },
  );

  @override
  Future<RequestActivity> getRequestActivity(String requestId) => _call(
    MessagesApiConstants.getRequestActivity,
    {'requestId': requestId},
    'We couldn’t check on this ride.',
    (json) {
      if (json is! Map) throw const ParsingException();
      return RideRequestModel.activity(Map<String, dynamic>.from(json));
    },
  );

  @override
  Future<ChatPerson?> respondToOffer(String offerId, {required bool approve}) =>
      _call(
        MessagesApiConstants.respondToOffer,
        {
          'offerId': offerId,
          'action': approve
              ? MessagesApiConstants.actionApprove
              : MessagesApiConstants.actionDecline,
        },
        approve
            ? 'We couldn’t approve this Ride Partner. Please try again.'
            : 'We couldn’t decline this offer. Please try again.',
        (json) {
          final driver = json is Map ? json['driver'] : null;
          return driver is Map
              ? RideRequestModel.person(Map<String, dynamic>.from(driver))
              : null;
        },
      );

  @override
  Future<void> cancelRideRequest(String requestId) => _call(
    MessagesApiConstants.cancelRideRequest,
    {'requestId': requestId, 'scope': MessagesApiConstants.scopeThis},
    'We couldn’t cancel your request. Please try again.',
    (_) {},
  );

  // ----------------------------------------------------- Ride Partner

  @override
  Future<List<RideRequest>> getOpenRequests() async {
    try {
      return await _call(
        MessagesApiConstants.getOpenRequests,
        const {},
        'We couldn’t load ride requests. Pull to refresh.',
        _incomingList,
      );
    } on UnauthorizedException {
      rethrow;
    } on ServerException catch (e) {
      if (notAPartnerCodes.contains(e.code)) return const [];
      rethrow;
    }
  }

  @override
  Future<List<RideRequest>> getMyDrives(String scope) async {
    try {
      return await _call(
        MessagesApiConstants.getMyDrives,
        {'scope': scope},
        'We couldn’t load your drives. Pull to refresh.',
        (json) {
          if (json is! Map) throw const ParsingException();
          return [
            ..._incomingList(json['drives'] ?? const []),
            ..._incomingList(json['pendingOffers'] ?? const []),
          ];
        },
      );
    } on UnauthorizedException {
      rethrow;
    } on ServerException catch (e) {
      if (notAPartnerCodes.contains(e.code)) return const [];
      rethrow;
    }
  }

  static List<RideRequest> _incomingList(Object? json) {
    if (json is! List) throw const ParsingException();
    return [
      for (final row in json.whereType<Map>())
        ?RideRequestModel.incoming(Map<String, dynamic>.from(row)),
    ];
  }

  @override
  Future<OfferOutcome> offerRide(String requestId) => _call(
    MessagesApiConstants.offerRide,
    {'requestId': requestId, 'scope': MessagesApiConstants.scopeThis},
    'We couldn’t send your offer. Please try again.',
    (json) => RideRequestModel.offerOutcome(json, requestId),
  );

  @override
  Future<void> withdrawOffer(String offerId) => _call(
    MessagesApiConstants.withdrawOffer,
    {'offerId': offerId, 'scope': MessagesApiConstants.scopeThis},
    'We couldn’t withdraw your offer. Please try again.',
    (_) {},
  );

  @override
  Future<void> passRequest(String requestId) async {
    try {
      await _apiClient.rpc<void>(
        MessagesApiConstants.passRideRequest,
        params: {'requestId': requestId},
        parser: (_) {},
      );
    } on ServerException catch (e) {
      // Not deployed yet: the device keeps the pass on its own.
      if (!isMissingFunction(e)) rethrow;
    }
  }

  @override
  Future<void> driverCancelRide(String requestId) => _call(
    MessagesApiConstants.driverCancelRide,
    {'requestId': requestId, 'scope': MessagesApiConstants.scopeThis},
    'We couldn’t cancel this ride. Please try again.',
    (_) {},
  );

  // ------------------------------------------------------------- chat

  @override
  Future<List<RideChat>> getMyChats() => _call(
    MessagesApiConstants.getMyRideChats,
    const {},
    'We couldn’t load your chats. Pull to refresh.',
    (json) {
      if (json is! List) throw const ParsingException();
      return RideChatModel.chatsFromJson(json);
    },
    chat: true,
  );

  @override
  Future<List<ChatMessage>> getMessages(String requestId, String driverId) =>
      _call(
        MessagesApiConstants.getRideMessages,
        {'requestId': requestId, 'driverId': driverId},
        'We couldn’t load the messages.',
        (json) {
          if (json is! List) throw const ParsingException();
          return RideChatModel.messagesFromJson(json);
        },
        chat: true,
      );

  @override
  Future<ChatMessage> sendMessage(
    String requestId,
    String driverId,
    String body,
  ) => _call(
    MessagesApiConstants.sendRideMessage,
    {'requestId': requestId, 'driverId': driverId, 'body': body},
    'We couldn’t send your message. Please try again.',
    (json) {
      final message = json is Map
          ? RideChatModel.messageFromJson(Map<String, dynamic>.from(json))
          : null;
      if (message == null) throw const ParsingException();
      return message;
    },
    chat: true,
  );

  // ------------------------------------------------------ ride groups

  @override
  Future<List<RideGroup>> getMyGroups() => _call(
    MessagesApiConstants.getMyRideGroups,
    const {},
    'We couldn’t load your groups. Pull to refresh.',
    (json) {
      if (json is! List) throw const ParsingException();
      return RideGroupModel.groupsFromJson(json);
    },
    groups: true,
  );

  @override
  Future<RideGroupDetails> getGroup(String groupId) => _call(
    MessagesApiConstants.getRideGroup,
    {'groupId': groupId},
    'We couldn’t load this group.',
    (json) {
      final group = RideGroupModel.detailsFromJson(json);
      if (group == null) throw const ParsingException();
      return group;
    },
    groups: true,
  );

  @override
  Future<List<GroupMessage>> getGroupMessages(String groupId) => _call(
    MessagesApiConstants.getRideGroupMessages,
    {'groupId': groupId},
    'We couldn’t load the messages.',
    (json) {
      if (json is! List) throw const ParsingException();
      return RideGroupModel.messagesFromJson(json);
    },
    groups: true,
  );

  @override
  Future<GroupMessage> postRideAsk(
    String groupId,
    List<Map<String, dynamic>> rides,
    String summary,
  ) => _askCall(
    MessagesApiConstants.postRideAsk,
    {'groupId': groupId, 'rides': rides, 'summary': summary},
    'We couldn’t post your ride. Please try again.',
    (json) {
      final message = json is Map
          ? RideGroupModel.messageFromJson(Map<String, dynamic>.from(json))
          : null;
      if (message == null) throw const ParsingException();
      return message;
    },
  );

  @override
  Future<List<RideAsk>> getGroupRideAsks(String groupId) => _askCall(
    MessagesApiConstants.getGroupRideAsks,
    {'groupId': groupId},
    'We couldn’t load the rides in this group.',
    (json) => [
      if (json is List)
        for (final item in json.whereType<Map>())
          ?rideAskFromJson(Map<String, dynamic>.from(item)),
    ],
  );

  @override
  Future<void> helpWithRideAsk(String askId) async {
    try {
      await _askCall(
        MessagesApiConstants.helpWithRideAsk,
        {'askId': askId},
        'We couldn’t offer to help. Please try again.',
        (_) {},
      );
    } on ServerException catch (e) {
      // Worded for the driver who tapped "I can help".
      final text = _helpErrors[e.code];
      if (text == null) rethrow;
      throw ServerException(text, e.statusCode, e.code, e.data);
    }
  }

  static const Map<String, String> _helpErrors = {
    'already_taken': 'Another parent already offered to drive this ride.',
    'request_not_open': 'This ride isn’t open any more.',
    'not_eligible': 'You live too far from this pick-up to drive it.',
    'driver_busy': 'You’re already driving another ride around then.',
    'duplicate_request':
        'This parent already has a ride request around that time.',
    'pickup_too_soon': 'This ride starts too soon to be offered now.',
    'not_a_driver': 'Only parents approved to drive can offer rides.',
  };

  static RideAsk? rideAskFromJson(Map<String, dynamic> map) {
    final id = map.readString('id');
    if (id == null) return null;
    return RideAsk(
      id: id,
      messageId: map.readString('messageId'),
      isMine: map.readBool('isMine') ?? false,
      status: RideAskStatus.parse(map.readString('status')),
      helperName: map.readString('helperName'),
      canHelp: map.readBool('canHelp') ?? false,
      days: map.readInt('days') ?? 1,
      isHelper: map.readBool('isHelper') ?? false,
      rideStatus: map.readString('rideStatus'),
      requestIds: [
        if (map['requestIds'] case final List<dynamic> ids)
          for (final id in ids)
            if (id is String) id,
      ],
    );
  }

  /// [_call] for ride-ask RPCs: a missing function (SQL not applied)
  /// becomes [MessagesApiConstants.rideAsksMissing].
  Future<T> _askCall<T>(
    String name,
    Map<String, dynamic> params,
    String fallback,
    ResponseParser<T> parser,
  ) async {
    try {
      return await _apiClient.rpc<T>(name, params: params, parser: parser);
    } on UnauthorizedException {
      rethrow;
    } on ServerException catch (e) {
      if (isMissingFunction(e)) {
        throw ServerException(
          'Ride cards aren’t set up on the server yet.',
          e.statusCode,
          MessagesApiConstants.rideAsksMissing,
          e.data,
        );
      }
      // Same wording rules as [_call] (never re-sends the request).
      final known = ApiErrorMessages.forCode(e.code) != null;
      final serverDown = e.code == null && (e.statusCode ?? 0) >= 500;
      if (known || serverDown) rethrow;
      throw ServerException(fallback, e.statusCode, e.code, e.data);
    }
  }

  @override
  Future<GroupMessage> sendGroupMessage(String groupId, String body) => _call(
    MessagesApiConstants.sendRideGroupMessage,
    {'groupId': groupId, 'body': body},
    'We couldn’t send your message. Please try again.',
    (json) {
      final message = json is Map
          ? RideGroupModel.messageFromJson(Map<String, dynamic>.from(json))
          : null;
      if (message == null) throw const ParsingException();
      return message;
    },
    groups: true,
  );

  @override
  Future<void> markGroupRead(String groupId) => _call(
    MessagesApiConstants.markRideGroupRead,
    {'groupId': groupId},
    'We couldn’t update this group.',
    (_) {},
    groups: true,
  );

  @override
  Future<String> createGroup({
    required String name,
    required List<String> memberIds,
    String? schoolId,
  }) => _call(
    MessagesApiConstants.createRideGroup,
    {'name': name, 'memberIds': memberIds, 'schoolId': ?schoolId},
    'We couldn’t start the group. Please try again.',
    (json) {
      final id = RideGroupModel.idFromJson(json);
      if (id == null) throw const ParsingException();
      return id;
    },
    groups: true,
  );

  @override
  Future<int> addGroupMembers(String groupId, List<String> memberIds) => _call(
    MessagesApiConstants.addRideGroupMembers,
    {'groupId': groupId, 'memberIds': memberIds},
    'We couldn’t add these parents. Please try again.',
    (json) => json is Map
        ? (Map<String, dynamic>.from(json).readInt('added') ?? 0)
        : 0,
    groups: true,
  );

  @override
  Future<void> leaveGroup(String groupId) => _call(
    MessagesApiConstants.leaveRideGroup,
    {'groupId': groupId},
    'We couldn’t leave the group. Please try again.',
    (_) {},
    groups: true,
  );

  @override
  Future<void> renameGroup(String groupId, String name) => _call(
    MessagesApiConstants.renameRideGroup,
    {'groupId': groupId, 'name': name},
    'We couldn’t rename the group. Please try again.',
    (_) {},
    groups: true,
  );

  @override
  Future<void> setGroupMuted(String groupId, {required bool muted}) => _call(
    MessagesApiConstants.setRideGroupMuted,
    {'groupId': groupId, 'muted': muted},
    'We couldn’t change notifications. Please try again.',
    (_) {},
    groups: true,
  );

  @override
  Future<List<RideGroupMember>> getGroupCandidates(String? groupId) => _call(
    MessagesApiConstants.getRideGroupCandidates,
    {'groupId': ?groupId},
    'We couldn’t load parents to add.',
    (json) {
      if (json is! List) throw const ParsingException();
      return RideGroupModel.membersFromJson(json);
    },
    groups: true,
  );

  // ----------------------------------------------------------- photos

  @override
  Future<Map<String, String>> signKidPhotos(List<String> paths) async {
    if (paths.isEmpty) return const {};
    final signedAt = _photosSignedAt;
    final fresh =
        signedAt != null &&
        DateTime.now().difference(signedAt) <
            const Duration(
              seconds: MessagesApiConstants.signedUrlSeconds - 600,
            );
    if (fresh && paths.every(_photoUrls.containsKey)) return _photoUrls;
    try {
      final storageBase = '${_apiClient.baseUrl}${ApiConstants.storagePrefix}';
      final urls = await _apiClient.post<Map<String, String>>(
        '${ApiConstants.storagePrefix}/object/sign/'
        '${MessagesApiConstants.kidPhotosBucket}',
        data: {
          'expiresIn': MessagesApiConstants.signedUrlSeconds,
          'paths': paths,
        },
        parser: (json) {
          final out = <String, String>{};
          if (json is! List) return out;
          for (final item in json.whereType<Map>()) {
            final path = item['path'];
            final signed = item['signedURL'] ?? item['signedUrl'];
            if (path is String && signed is String) {
              out[path] = signed.startsWith('http')
                  ? signed
                  : '$storageBase$signed';
            }
          }
          return out;
        },
      );
      _photoUrls
        ..clear()
        ..addAll(urls);
      _photosSignedAt = DateTime.now();
      return _photoUrls;
    } on AppException {
      return const {};
    }
  }

  // ------------------------------------------------------------ errors

  /// PostgREST answers 404 / `PGRST202` for an RPC that isn't deployed.
  static bool isMissingFunction(ServerException e) =>
      e.data['code'] == MessagesApiConstants.functionNotFound ||
      (e.statusCode == 404 && e.code == null);

  /// Runs an RPC; known codes keep their friendly text (see
  /// [ApiErrorMessages]), anything else gets [fallback]. For [chat] RPCs a
  /// missing function becomes [MessagesApiConstants.chatMissing], for
  /// [groups] RPCs [MessagesApiConstants.groupsMissing].
  Future<T> _call<T>(
    String name,
    Map<String, dynamic> params,
    String fallback,
    ResponseParser<T> parser, {
    bool chat = false,
    bool groups = false,
  }) async {
    try {
      return await _apiClient.rpc<T>(name, params: params, parser: parser);
    } on UnauthorizedException {
      rethrow;
    } on ServerException catch (e) {
      if (chat && isMissingFunction(e)) {
        throw ServerException(
          MessagesApiConstants.chatMissingMessage,
          e.statusCode,
          MessagesApiConstants.chatMissing,
          e.data,
        );
      }
      if (groups && isMissingFunction(e)) {
        throw ServerException(
          MessagesApiConstants.groupsMissingMessage,
          e.statusCode,
          MessagesApiConstants.groupsMissing,
          e.data,
        );
      }
      final known = ApiErrorMessages.forCode(e.code) != null;
      final serverDown = e.code == null && (e.statusCode ?? 0) >= 500;
      if (known || serverDown) rethrow;
      throw ServerException(fallback, e.statusCode, e.code, e.data);
    }
  }
}
