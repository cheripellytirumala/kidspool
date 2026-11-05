import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:kidspool/common/core/di/injection_container.dart';
import 'package:kidspool/common/core/error/failures.dart';
import 'package:kidspool/common/core/router/app_routes.dart';
import 'package:kidspool/common/presentation/theme/app_theme.dart';
import 'package:kidspool/common/presentation/widgets/app_toggle.dart';
import 'package:kidspool/messages/core/constants/messages_api_constants.dart';
import 'package:kidspool/messages/domain/entities/chat_person.dart';
import 'package:kidspool/messages/domain/entities/ride_chat.dart';
import 'package:kidspool/messages/domain/entities/ride_request.dart';
import 'package:kidspool/messages/domain/repositories/messages_repository.dart';
import 'package:kidspool/messages/domain/usecases/cancel_ride_request.dart';
import 'package:kidspool/messages/domain/usecases/driver_cancel_ride.dart';
import 'package:kidspool/messages/domain/usecases/get_drive_request.dart';
import 'package:kidspool/messages/domain/usecases/get_my_chats.dart';
import 'package:kidspool/messages/domain/usecases/get_my_ride_request.dart';
import 'package:kidspool/messages/domain/usecases/get_request_activity.dart';
import 'package:kidspool/messages/domain/usecases/get_requests_inbox.dart';
import 'package:kidspool/messages/domain/usecases/get_ride_messages.dart';
import 'package:kidspool/messages/domain/usecases/offer_ride.dart';
import 'package:kidspool/messages/domain/usecases/pass_ride_request.dart';
import 'package:kidspool/messages/domain/usecases/respond_to_offer.dart';
import 'package:kidspool/messages/domain/usecases/send_ride_message.dart';
import 'package:kidspool/messages/domain/usecases/withdraw_offer.dart';
import 'package:kidspool/messages/presentation/providers/messages_provider.dart';
import 'package:kidspool/messages/domain/usecases/get_my_rides.dart';
import 'package:kidspool/profile/domain/entities/ride_mode.dart';
import 'package:kidspool/profile/domain/repositories/profile_repository.dart';
import 'package:kidspool/profile/domain/usecases/change_ride_mode.dart';
import 'package:kidspool/rides/presentation/providers/rides_provider.dart';
import 'package:kidspool/rides/presentation/screens/rides_screen.dart';
import 'package:kidspool/messages/presentation/providers/ride_chat_provider.dart';
import 'package:kidspool/messages/presentation/providers/ride_group_info_provider.dart';
import 'package:kidspool/messages/presentation/providers/ride_request_detail_provider.dart';
import 'package:kidspool/messages/presentation/screens/messages_screen.dart';
import 'package:kidspool/messages/presentation/screens/ride_chat_screen.dart';
import 'package:kidspool/messages/presentation/screens/ride_group_info_screen.dart';
import 'package:kidspool/messages/presentation/screens/ride_request_detail_screen.dart';

const _me = 'me-id';
const _jen = ChatPerson(
  id: 'jen-id',
  firstName: 'Jen',
  lastName: 'Park',
  initials: 'JP',
  distanceMiles: 1.1,
  ridesGiven: 3,
  kidsAtSchool: ['Mia'],
);

final _pickup = DateTime(2026, 11, 5, 8, 30);

final _myRequest = RideRequest(
  id: 'mine-1',
  isMine: true,
  status: RideRequestStatus.open,
  pickupAt: _pickup,
  pickupLabel: 'Home',
  destinationName: 'Lincoln Elementary',
  kids: const [
    ChatKid(firstName: 'Emma'),
    ChatKid(firstName: 'Noah'),
  ],
  offers: [RideOffer(offerId: 'o1', partner: _jen, createdAt: _pickup)],
  openDaysInSeries: 2,
);

final _incoming = RideRequest(
  id: 'in-1',
  isMine: false,
  status: RideRequestStatus.open,
  pickupAt: _pickup,
  pickupLabel: 'Home',
  destinationName: 'Bluewave Swim School of the Bay Area',
  kids: const [ChatKid(firstName: 'Ethan')],
  parent: const ChatPerson(
    firstName: 'Rachel',
    lastName: 'Singh',
    initials: 'RS',
  ),
  distanceMiles: 1.1,
  note: 'Could anyone help Ethan get to swim? Happy to return the favour',
  youAreBusy: true,
);

/// In-memory [MessagesRepository]. [chatDeployed] false = chat SQL missing.
class FakeMessagesRepository implements MessagesRepository {
  FakeMessagesRepository({this.chatDeployed = true});

  bool chatDeployed;
  int messageCalls = 0;
  final List<ChatMessage> sent = [];

  static const _missing = ServerFailure(
    MessagesApiConstants.chatMissingMessage,
    statusCode: 404,
    code: MessagesApiConstants.chatMissing,
  );

  @override
  String? get myUserId => _me;

  @override
  bool get isSignedIn => true;

  @override
  Future<Either<Failure, RequestsInbox>> getRequestsInbox() async =>
      Right(RequestsInbox(mine: [_myRequest], incoming: [_incoming]));

  @override
  Future<Either<Failure, List<RideRequest>>> getMyRides(String scope) async =>
      Right(scope == MessagesApiConstants.scopePast ? const [] : [_myRequest]);

  @override
  Future<Either<Failure, RideRequest>> getMyRequest(String id) async =>
      Right(_myRequest);

  @override
  Future<Either<Failure, RideRequest>> getDriveRequest(String id) async =>
      Right(_incoming);

  @override
  Future<Either<Failure, RequestActivity>> getRequestActivity(
    String id,
  ) async => const Right(RequestActivity(notifiedCount: 6));

  @override
  Future<Either<Failure, ChatPerson?>> respondToOffer(
    String offerId, {
    required bool approve,
  }) async => const Right(_jen);

  @override
  Future<Either<Failure, Unit>> cancelRideRequest(String id) async =>
      const Right(unit);

  @override
  Future<Either<Failure, OfferOutcome>> offerRide(String id) async =>
      const Right(OfferOutcome(offerId: 'o9', confirmed: false));

  @override
  Future<Either<Failure, Unit>> withdrawOffer(String id) async =>
      const Right(unit);

  @override
  Future<Either<Failure, Unit>> driverCancelRide(String id) async =>
      const Right(unit);

  @override
  Future<Either<Failure, Unit>> passRequest(String id) async =>
      const Right(unit);

  @override
  Future<Either<Failure, List<RideChat>>> getMyChats() async {
    if (!chatDeployed) return const Left(_missing);
    return Right([
      RideChat(
        requestId: 'mine-1',
        driverId: 'jen-id',
        iAmDriver: false,
        status: RideRequestStatus.open,
        other: _jen,
        lastMessage: 'Happy to take Emma too — we go every Tuesday morning',
        lastAt: DateTime.now(),
        unread: 1,
      ),
    ]);
  }

  @override
  Future<Either<Failure, List<ChatMessage>>> getMessages({
    required String requestId,
    required String driverId,
  }) async {
    messageCalls++;
    if (!chatDeployed) return const Left(_missing);
    final now = DateTime.now();
    return Right([
      ChatMessage(
        id: 'm1',
        senderId: 'jen-id',
        body: 'Happy to help! I drive to Lincoln most mornings 🚗',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      ChatMessage(
        id: 'm2',
        senderId: _me,
        body: 'Thank you! This makes mornings so much easier.',
        createdAt: now,
      ),
      ...sent,
    ]);
  }

  @override
  Future<Either<Failure, ChatMessage>> sendMessage({
    required String requestId,
    required String driverId,
    required String body,
  }) async {
    if (!chatDeployed) return const Left(_missing);
    final m = ChatMessage(
      id: 's${sent.length}',
      senderId: _me,
      body: body,
      createdAt: DateTime.now(),
    );
    sent.add(m);
    return Right(m);
  }
}

/// Only ride mode is used by the Rides tab.
class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this.mode);

  RideMode mode;

  @override
  RideMode getRideMode() => mode;

  @override
  Future<Either<Failure, RideMode>> setRideMode(RideMode m) async =>
      Right(mode = m);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _register(
  FakeMessagesRepository repo, {
  RideMode rideMode = RideMode.both,
}) async {
  await sl.reset();
  final profile = _FakeProfileRepository(rideMode);
  sl
    ..registerFactory<RidesProvider>(
      () => RidesProvider(
        getRequestsInbox: GetRequestsInbox(repo),
        getMyRides: GetMyRides(repo),
        profile: profile,
        changeRideMode: ChangeRideMode(profile),
      ),
    )
    ..registerFactory<MessagesProvider>(
      () => MessagesProvider(
        getRequestsInbox: GetRequestsInbox(repo),
        getMyChats: GetMyChats(repo),
        offerRide: OfferRide(repo),
        passRideRequest: PassRideRequest(repo),
        withdrawOffer: WithdrawOffer(repo),
        respondToOffer: RespondToOffer(repo),
        myUserId: () => repo.myUserId,
      ),
    )
    ..registerFactory<RideRequestDetailProvider>(
      () => RideRequestDetailProvider(
        getMyRideRequest: GetMyRideRequest(repo),
        getDriveRequest: GetDriveRequest(repo),
        getRequestActivity: GetRequestActivity(repo),
        offerRide: OfferRide(repo),
        passRideRequest: PassRideRequest(repo),
        withdrawOffer: WithdrawOffer(repo),
        respondToOffer: RespondToOffer(repo),
        cancelRideRequest: CancelRideRequest(repo),
        myUserId: () => repo.myUserId,
      ),
    )
    ..registerFactory<RideChatProvider>(
      () => RideChatProvider(
        getMyRideRequest: GetMyRideRequest(repo),
        getDriveRequest: GetDriveRequest(repo),
        getRideMessages: GetRideMessages(repo),
        sendRideMessage: SendRideMessage(repo),
        respondToOffer: RespondToOffer(repo),
        offerRide: OfferRide(repo),
        withdrawOffer: WithdrawOffer(repo),
      ),
    )
    ..registerFactory<RideGroupInfoProvider>(
      () => RideGroupInfoProvider(
        getMyRideRequest: GetMyRideRequest(repo),
        getDriveRequest: GetDriveRequest(repo),
        getRequestActivity: GetRequestActivity(repo),
        cancelRideRequest: CancelRideRequest(repo),
        withdrawOffer: WithdrawOffer(repo),
        driverCancelRide: DriverCancelRide(repo),
      ),
    );
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Object? arguments,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      onGenerateRoute: (s) => MaterialPageRoute<void>(
        settings: s,
        builder: (_) => const Scaffold(),
      ),
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(
          settings: RouteSettings(name: '/x', arguments: arguments),
          builder: (_) => screen,
        ),
      ],
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

const _chatArgs = RideChatArgs(
  requestId: 'mine-1',
  driverId: 'jen-id',
  iAmDriver: false,
  otherName: 'Jen',
  otherInitials: 'JP',
);

void main() {
  setUpAll(() async {
    final loader = FontLoader('HankenGrotesk');
    for (final w in [400, 500, 600, 700]) {
      final bytes = File('assets/fonts/HankenGrotesk-$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  for (final size in const [Size(390, 844), Size(320, 568)]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('F24 chats + F24a requests render with data at $tag', (
      tester,
    ) async {
      await _register(FakeMessagesRepository());
      await _pump(tester, const MessagesScreen(), size: size);
      expect(find.text('Jen P.'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(RegExp('^Requests')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Rachel needs a ride'), findsOneWidget);
      expect(find.text('I can help'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _dispose(tester);
    });

    testWidgets('F19c rides tab: requests, upcoming, past at $tag', (
      tester,
    ) async {
      await _register(FakeMessagesRepository());
      await _pump(tester, const RidesScreen(), size: size);
      expect(find.text('Your rides'), findsOneWidget);
      expect(find.text('Available to help families near you'), findsOneWidget);
      expect(find.text('View request'), findsOneWidget);
      expect(find.textContaining('Rachel'), findsWidgets);

      await tester.tap(find.bySemanticsLabel(RegExp('^Upcoming')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Asking'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(RegExp('^Past')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('No past rides yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _dispose(tester);
    });

    testWidgets(
      'F19c not available: requests hidden, toggle turns on at $tag',
      (tester) async {
        await _register(FakeMessagesRepository(), rideMode: RideMode.seeker);
        await _pump(tester, const RidesScreen(), size: size);
        // Opens on Upcoming when the parent only gets rides.
        expect(find.text('Asking'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel(RegExp('^Requests')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('You’re not helping right now'), findsOneWidget);
        await tester.tap(find.byType(AppToggle));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('View request'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _dispose(tester);
      },
    );

    testWidgets('A7a incoming request renders at $tag', (tester) async {
      await _register(FakeMessagesRepository());
      await _pump(
        tester,
        const RideRequestDetailScreen(),
        arguments: const RideRequestArgs(requestId: 'in-1'),
        size: size,
      );
      expect(find.text('Rachel needs a ride for Ethan'), findsOneWidget);
      expect(find.text('Yes, I can help'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _dispose(tester);
    });

    testWidgets('A7a own request with offers renders at $tag', (tester) async {
      await _register(FakeMessagesRepository());
      await _pump(
        tester,
        const RideRequestDetailScreen(),
        arguments: const RideRequestArgs(requestId: 'mine-1', isMine: true),
        size: size,
      );
      expect(find.text('Jen P. can drive'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _dispose(tester);
    });

    testWidgets('F19 chat renders, polls and sends at $tag', (tester) async {
      final repo = FakeMessagesRepository();
      await _register(repo);
      await _pump(
        tester,
        const RideChatScreen(),
        arguments: _chatArgs,
        size: size,
      );
      expect(find.text('Jen offered to drive'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.textContaining('This makes mornings'), findsOneWidget);
      final calls = repo.messageCalls;
      await tester.pump(MessagesApiConstants.threadPollInterval);
      expect(repo.messageCalls, greaterThan(calls));

      await tester.enterText(find.byType(TextField), 'See you at 8:30');
      await tester.tap(find.bySemanticsLabel('Send'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('See you at 8:30'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _dispose(tester);
    });

    testWidgets('GC6 group info renders at $tag', (tester) async {
      await _register(FakeMessagesRepository());
      await _pump(
        tester,
        const RideGroupInfoScreen(),
        arguments: _chatArgs,
        size: size,
      );
      expect(find.text('Home → Lincoln Elementary'), findsOneWidget);
      expect(find.textContaining('sent to 6 families'), findsOneWidget);
      expect(find.text('Jen P.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _dispose(tester);
    });
  }

  testWidgets('chat SQL missing: cards work, composer explains, polling off', (
    tester,
  ) async {
    final repo = FakeMessagesRepository(chatDeployed: false);
    await _register(repo);
    await _pump(tester, const RideChatScreen(), arguments: _chatArgs);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text(MessagesApiConstants.chatMissingMessage), findsOneWidget);
    final calls = repo.messageCalls;
    await tester.pump(MessagesApiConstants.threadPollInterval * 3);
    expect(repo.messageCalls, calls);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('chat SQL missing: Chats tab lists ride threads', (tester) async {
    await _register(FakeMessagesRepository(chatDeployed: false));
    await _pump(tester, const MessagesScreen());
    expect(find.text('Jen offered to drive'), findsOneWidget);
    expect(find.textContaining('isn’t set up'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  test('polling stops on dispose and pauses on stop', () async {
    final repo = FakeMessagesRepository();
    await _register(repo);
    final p = sl<RideChatProvider>();
    await p.open(_chatArgs);
    p.startPolling();
    expect(p.isPolling, isTrue);
    p.stopPolling();
    expect(p.isPolling, isFalse);
    p.startPolling();
    p.dispose();
    expect(p.isPolling, isFalse);
  });
}
