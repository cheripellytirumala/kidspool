import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/error_handler.dart';
import '../../../common/core/error/exceptions.dart';
import '../../../common/core/error/failures.dart';
import '../../../common/core/network/auth_token_provider.dart';
import '../../core/constants/messages_api_constants.dart';
import '../../domain/entities/chat_person.dart';
import '../../domain/entities/ride_chat.dart';
import '../../domain/entities/ride_request.dart';
import '../../domain/repositories/messages_repository.dart';
import '../data_sources/remote/messages_remote_data_source.dart';

class MessagesRepositoryImpl implements MessagesRepository {
  MessagesRepositoryImpl({
    required MessagesRemoteDataSource remoteDataSource,
    required AuthTokenProvider tokenProvider,
  }) : _remote = remoteDataSource,
       _tokens = tokenProvider;

  static const String _tag = 'MessagesRepository';

  final MessagesRemoteDataSource _remote;
  final AuthTokenProvider _tokens;

  /// Requests passed on with "Not this time" (this app run only, like the
  /// previous app: there is no API for it).
  final Set<String> _passed = {};

  @override
  String? get myUserId => _tokens.session?.userId;

  @override
  bool get isSignedIn => _tokens.hasSession;

  // ---------------------------------------------------------- requests

  @override
  Future<Either<Failure, RequestsInbox>> getRequestsInbox() =>
      ErrorHandler.guard(() async {
        final lists = await Future.wait([
          _remote.getMyOpenRequests(),
          _remote.getOpenRequests(),
          _remote.getMyDrives(MessagesApiConstants.scopeUpcoming),
        ], eagerError: true);
        final [mine, open, drives] = lists;

        // Offers on each own open request (get_ride_request).
        final detailed = await Future.wait([
          for (final r in mine)
            _remote.getMyRequest(r.id).catchError((Object _) => r),
        ]);

        // Open requests sent to me, plus my pending offers.
        final byId = <String, RideRequest>{};
        for (final r in open) {
          byId[r.id] = r;
        }
        for (final r in drives) {
          if (r.offered && r.isOpen) byId[r.id] = r;
        }
        final incoming =
            byId.values
                .where((r) => r.isOpen && !_passed.contains(r.id))
                .toList()
              ..sort((a, b) => a.pickupAt.compareTo(b.pickupAt));
        return RequestsInbox(
          mine: await _withKidPhotos(detailed),
          incoming: incoming,
        );
      }, tag: _tag);

  @override
  Future<Either<Failure, RideRequest>> getMyRequest(String requestId) =>
      ErrorHandler.guard(() async {
        final request = await _remote.getMyRequest(requestId);
        return (await _withKidPhotos([request])).first;
      }, tag: _tag);

  @override
  Future<Either<Failure, RideRequest>> getDriveRequest(String requestId) =>
      ErrorHandler.guard(() async {
        for (final load in <Future<List<RideRequest>> Function()>[
          () => _remote.getMyDrives(MessagesApiConstants.scopeUpcoming),
          _remote.getOpenRequests,
          () => _remote.getMyDrives(MessagesApiConstants.scopePast),
        ]) {
          for (final r in await load()) {
            if (r.id == requestId) return r;
          }
        }
        throw const ServerException(
          'This ride isn’t available any more.',
          404,
          'ride_not_found',
        );
      }, tag: _tag);

  @override
  Future<Either<Failure, RequestActivity>> getRequestActivity(
    String requestId,
  ) => ErrorHandler.guard(
    () => _remote.getRequestActivity(requestId),
    tag: _tag,
  );

  @override
  Future<Either<Failure, ChatPerson?>> respondToOffer(
    String offerId, {
    required bool approve,
  }) => ErrorHandler.guard(
    () => _remote.respondToOffer(offerId, approve: approve),
    tag: _tag,
  );

  @override
  Future<Either<Failure, Unit>> cancelRideRequest(String requestId) =>
      ErrorHandler.guard(() async {
        await _remote.cancelRideRequest(requestId);
        return unit;
      }, tag: _tag);

  @override
  Future<Either<Failure, OfferOutcome>> offerRide(String requestId) =>
      ErrorHandler.guard(() => _remote.offerRide(requestId), tag: _tag);

  @override
  Future<Either<Failure, Unit>> withdrawOffer(String offerId) =>
      ErrorHandler.guard(() async {
        await _remote.withdrawOffer(offerId);
        return unit;
      }, tag: _tag);

  @override
  Future<Either<Failure, Unit>> driverCancelRide(String requestId) =>
      ErrorHandler.guard(() async {
        await _remote.driverCancelRide(requestId);
        return unit;
      }, tag: _tag);

  @override
  Future<Either<Failure, Unit>> passRequest(String requestId) async {
    _passed.add(requestId);
    return const Right(unit);
  }

  // -------------------------------------------------------------- chat

  @override
  Future<Either<Failure, List<RideChat>>> getMyChats() =>
      ErrorHandler.guard(_remote.getMyChats, tag: _tag);

  @override
  Future<Either<Failure, List<ChatMessage>>> getMessages({
    required String requestId,
    required String driverId,
  }) => ErrorHandler.guard(
    () => _remote.getMessages(requestId, driverId),
    tag: _tag,
  );

  @override
  Future<Either<Failure, ChatMessage>> sendMessage({
    required String requestId,
    required String driverId,
    required String body,
  }) {
    final text = body.trim();
    if (text.isEmpty || text.length > MessagesApiConstants.maxMessageLength) {
      return Future.value(
        const Left(
          ServerFailure(
            'Messages can be 1–2000 characters.',
            code: 'invalid_field',
          ),
        ),
      );
    }
    return ErrorHandler.guard(
      () => _remote.sendMessage(requestId, driverId, text),
      tag: _tag,
    );
  }

  // ------------------------------------------------------------ photos

  Future<List<RideRequest>> _withKidPhotos(List<RideRequest> requests) async {
    final paths = {
      for (final r in requests)
        for (final k in r.kids) ?k.photoPath,
    }.toList();
    if (paths.isEmpty) return requests;
    final urls = await _remote.signKidPhotos(paths);
    if (urls.isEmpty) return requests;
    return [
      for (final r in requests)
        r.copyWith(
          kids: [for (final k in r.kids) k.withPhotoUrl(urls[k.photoPath])],
        ),
    ];
  }
}
