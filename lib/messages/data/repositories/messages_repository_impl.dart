import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/error_handler.dart';
import '../../../common/core/error/exceptions.dart';
import '../../../common/core/error/failures.dart';
import '../../../common/core/network/auth_token_provider.dart';
import '../../../common/core/utils/logger.dart';
import '../../core/constants/messages_api_constants.dart';
import '../data_sources/local/passed_requests_store.dart';
import '../../domain/entities/chat_person.dart';
import '../../domain/entities/ride_chat.dart';
import '../../domain/entities/ride_ask.dart';
import '../../domain/entities/ride_group.dart';
import '../../domain/entities/ride_request.dart';
import '../../domain/repositories/messages_repository.dart';
import '../data_sources/remote/messages_remote_data_source.dart';

class MessagesRepositoryImpl implements MessagesRepository {
  MessagesRepositoryImpl({
    required MessagesRemoteDataSource remoteDataSource,
    required AuthTokenProvider tokenProvider,
    PassedRequestsStore? passedStore,
  }) : _remote = remoteDataSource,
       _tokens = tokenProvider,
       _passedStore = passedStore;

  static const String _tag = 'MessagesRepository';

  final MessagesRemoteDataSource _remote;
  final AuthTokenProvider _tokens;

  /// Requests passed on with "Not this time": saved on the device by
  /// [_passedStore] (there is no server API for it), plus this app run.
  final PassedRequestsStore? _passedStore;
  final Set<String> _passedThisRun = {};

  Set<String> get _passed => {
    ..._passedThisRun,
    ...?_passedStore?.read(myUserId),
  };

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
        final passed = _passed;
        final incoming =
            byId.values
                .where((r) => r.isOpen && !passed.contains(r.id))
                .toList()
              ..sort((a, b) => a.pickupAt.compareTo(b.pickupAt));
        return RequestsInbox(
          mine: await _withKidPhotos(detailed),
          incoming: incoming,
        );
      }, tag: _tag);

  @override
  Future<Either<Failure, List<RideRequest>>> getMyRides(String scope) =>
      ErrorHandler.guard(() async {
        final lists = await Future.wait([
          _remote.getMyRequests(scope),
          _remote.getMyDrives(scope),
        ], eagerError: true);
        final [mine, drives] = lists;
        final byId = <String, RideRequest>{
          for (final r in await _withKidPhotos(mine)) r.id: r,
          // Booked drives only; an open row here is a pending offer.
          for (final r in drives)
            if (!r.isOpen) r.id: r,
        };
        final past = scope == MessagesApiConstants.scopePast;
        return byId.values.toList()..sort(
          (a, b) => past
              ? b.pickupAt.compareTo(a.pickupAt)
              : a.pickupAt.compareTo(b.pickupAt),
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
    // Hidden on this device right away; the server copy keeps it hidden
    // after a reinstall or on another phone. A failed server call is
    // ignored: the device still remembers it.
    _passedThisRun.add(requestId);
    await _passedStore?.add(myUserId, requestId);
    try {
      await _remote.passRequest(requestId);
    } on Object catch (e) {
      AppLogger.warning('$_tag.passRequest: $e');
    }
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

  // ------------------------------------------------------- ride groups

  @override
  Future<Either<Failure, List<RideGroup>>> getMyGroups() =>
      ErrorHandler.guard(_remote.getMyGroups, tag: _tag);

  @override
  Future<Either<Failure, RideGroupDetails>> getGroup(String groupId) =>
      ErrorHandler.guard(() => _remote.getGroup(groupId), tag: _tag);

  @override
  Future<Either<Failure, List<GroupMessage>>> getGroupMessages(
    String groupId,
  ) => ErrorHandler.guard(() => _remote.getGroupMessages(groupId), tag: _tag);

  @override
  Future<Either<Failure, GroupMessage>> sendGroupMessage({
    required String groupId,
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
      () => _remote.sendGroupMessage(groupId, text),
      tag: _tag,
    );
  }

  @override
  Future<Either<Failure, GroupMessage>> postRideAsk({
    required String groupId,
    required List<Map<String, dynamic>> rides,
    required String summary,
  }) => ErrorHandler.guard(
    () => _remote.postRideAsk(groupId, rides, summary.trim()),
    tag: _tag,
  );

  @override
  Future<Either<Failure, List<RideAsk>>> getGroupRideAsks(String groupId) =>
      ErrorHandler.guard(() => _remote.getGroupRideAsks(groupId), tag: _tag);

  @override
  Future<Either<Failure, Unit>> helpWithRideAsk(String askId) =>
      ErrorHandler.guard(() async {
        await _remote.helpWithRideAsk(askId);
        return unit;
      }, tag: _tag);

  @override
  Future<Either<Failure, Unit>> markGroupRead(String groupId) =>
      ErrorHandler.guard(() async {
        await _remote.markGroupRead(groupId);
        return unit;
      }, tag: _tag);

  @override
  Future<Either<Failure, String>> createGroup({
    required String name,
    required List<String> memberIds,
    String? schoolId,
  }) {
    final text = name.trim();
    final invalid = _invalidName(text);
    if (invalid != null) return Future.value(Left(invalid));
    if (memberIds.isEmpty) {
      return Future.value(
        const Left(
          ServerFailure('Pick at least one family.', code: 'invalid_field'),
        ),
      );
    }
    if (memberIds.length + 1 > MessagesApiConstants.maxGroupMembers) {
      return Future.value(
        const Left(
          ServerFailure(
            'Groups can have up to 8 families.',
            code: 'group_full',
          ),
        ),
      );
    }
    return ErrorHandler.guard(
      () => _remote.createGroup(
        name: text,
        memberIds: memberIds,
        schoolId: schoolId,
      ),
      tag: _tag,
    );
  }

  @override
  Future<Either<Failure, int>> addGroupMembers({
    required String groupId,
    required List<String> memberIds,
  }) => ErrorHandler.guard(
    () => _remote.addGroupMembers(groupId, memberIds),
    tag: _tag,
  );

  @override
  Future<Either<Failure, Unit>> leaveGroup(String groupId) =>
      ErrorHandler.guard(() async {
        await _remote.leaveGroup(groupId);
        return unit;
      }, tag: _tag);

  @override
  Future<Either<Failure, Unit>> renameGroup({
    required String groupId,
    required String name,
  }) {
    final text = name.trim();
    final invalid = _invalidName(text);
    if (invalid != null) return Future.value(Left(invalid));
    return ErrorHandler.guard(() async {
      await _remote.renameGroup(groupId, text);
      return unit;
    }, tag: _tag);
  }

  @override
  Future<Either<Failure, Unit>> setGroupMuted({
    required String groupId,
    required bool muted,
  }) => ErrorHandler.guard(() async {
    await _remote.setGroupMuted(groupId, muted: muted);
    return unit;
  }, tag: _tag);

  @override
  Future<Either<Failure, List<RideGroupMember>>> getGroupCandidates(
    String? groupId,
  ) => ErrorHandler.guard(() => _remote.getGroupCandidates(groupId), tag: _tag);

  static Failure? _invalidName(String name) =>
      name.isEmpty || name.length > MessagesApiConstants.maxGroupNameLength
      ? const ServerFailure(
          'Group names can be 1–60 characters.',
          code: 'invalid_field',
        )
      : null;

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
