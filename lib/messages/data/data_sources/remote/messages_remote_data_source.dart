import '../../../../common/core/constants/api_constants.dart';
import '../../../../common/core/error/exceptions.dart';
import '../../../../common/core/network/api_client.dart';
import '../../../../common/core/network/api_error_messages.dart';
import '../../../core/constants/messages_api_constants.dart';
import '../../../domain/entities/chat_person.dart';
import '../../../domain/entities/ride_chat.dart';
import '../../../domain/entities/ride_request.dart';
import '../../models/ride_chat_model.dart';
import '../../models/ride_request_model.dart';

/// Ride + chat RPCs of the Messages tab. Throws only `AppException`s.
///
/// Chat calls throw a [ServerException] with code
/// [MessagesApiConstants.chatMissing] when the chat RPCs are not deployed.
abstract interface class MessagesRemoteDataSource {
  /// `get_my_ride_requests(upcoming)`, open ones only.
  Future<List<RideRequest>> getMyOpenRequests();

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

  Future<List<RideChat>> getMyChats();

  Future<List<ChatMessage>> getMessages(String requestId, String driverId);

  Future<ChatMessage> sendMessage(
    String requestId,
    String driverId,
    String body,
  );

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
  Future<List<RideRequest>> getMyOpenRequests() => _call(
    MessagesApiConstants.getMyRideRequests,
    const {'scope': MessagesApiConstants.scopeUpcoming},
    'We couldn’t load your ride requests. Pull to refresh.',
    (json) {
      if (json is! List) throw const ParsingException();
      return [
        for (final row in json.whereType<Map>())
          ?RideRequestModel.mine(Map<String, dynamic>.from(row)),
      ].where((r) => r.isOpen).toList(growable: false);
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
  /// missing function becomes [MessagesApiConstants.chatMissing].
  Future<T> _call<T>(
    String name,
    Map<String, dynamic> params,
    String fallback,
    ResponseParser<T> parser, {
    bool chat = false,
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
      final known = ApiErrorMessages.forCode(e.code) != null;
      final serverDown = e.code == null && (e.statusCode ?? 0) >= 500;
      if (known || serverDown) rethrow;
      throw ServerException(fallback, e.statusCode, e.code, e.data);
    }
  }
}
