import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:kidspool/common/core/di/injection_container.dart';
import 'package:kidspool/common/core/error/exceptions.dart';
import 'package:kidspool/common/core/error/failures.dart';
import 'package:kidspool/common/core/network/api_client.dart';
import 'package:kidspool/common/core/router/app_routes.dart';
import 'package:kidspool/common/core/usecase/usecase.dart';
import 'package:kidspool/common/presentation/state/nav_badges.dart';
import 'package:kidspool/common/presentation/theme/app_theme.dart';
import 'package:kidspool/common/presentation/widgets/app_toggle.dart';
import 'package:kidspool/home/domain/entities/family.dart';
import 'package:kidspool/home/domain/repositories/home_repository.dart';
import 'package:kidspool/home/domain/usecases/get_families_near_me.dart';
import 'package:kidspool/home/presentation/providers/families_near_you_provider.dart';
import 'package:kidspool/messages/core/constants/messages_api_constants.dart';
import 'package:kidspool/messages/domain/usecases/create_ride_group.dart';
import 'package:kidspool/messages/data/data_sources/remote/messages_remote_data_source.dart';
import 'package:kidspool/messages/data/models/ride_group_model.dart';
import 'package:kidspool/messages/domain/entities/chat_person.dart';
import 'package:kidspool/messages/domain/entities/ride_chat.dart';
import 'package:kidspool/messages/domain/entities/ride_group.dart';
import 'package:kidspool/messages/domain/entities/ride_request.dart';
import 'package:kidspool/messages/domain/repositories/messages_repository.dart';
import 'package:kidspool/messages/domain/usecases/add_group_members.dart';
import 'package:kidspool/messages/domain/usecases/get_group_candidates.dart';
import 'package:kidspool/messages/domain/usecases/get_group_messages.dart';
import 'package:kidspool/messages/domain/usecases/get_my_chats.dart';
import 'package:kidspool/messages/domain/usecases/get_my_ride_groups.dart';
import 'package:kidspool/messages/domain/usecases/get_requests_inbox.dart';
import 'package:kidspool/messages/domain/usecases/get_ride_group.dart';
import 'package:kidspool/messages/domain/usecases/leave_ride_group.dart';
import 'package:kidspool/messages/domain/usecases/mark_group_read.dart';
import 'package:kidspool/messages/domain/usecases/offer_ride.dart';
import 'package:kidspool/messages/domain/usecases/pass_ride_request.dart';
import 'package:kidspool/messages/domain/usecases/rename_ride_group.dart';
import 'package:kidspool/messages/domain/usecases/respond_to_offer.dart';
import 'package:kidspool/messages/domain/usecases/send_group_message.dart';
import 'package:kidspool/messages/domain/usecases/set_group_muted.dart';
import 'package:kidspool/messages/domain/usecases/withdraw_offer.dart';
import 'package:kidspool/messages/presentation/providers/group_chat_provider.dart';
import 'package:kidspool/messages/presentation/providers/group_info_provider.dart';
import 'package:kidspool/messages/presentation/providers/messages_badge_counter.dart';
import 'package:kidspool/messages/presentation/providers/messages_provider.dart';
import 'package:kidspool/messages/presentation/screens/group_chat_screen.dart';
import 'package:kidspool/messages/presentation/screens/group_info_screen.dart';
import 'package:kidspool/messages/presentation/screens/messages_screen.dart';

const _me = 'me-id';

const _missing = ServerFailure(
  MessagesApiConstants.groupsMissingMessage,
  statusCode: 404,
  code: MessagesApiConstants.groupsMissing,
);

final _now = DateTime.now();

final _incoming = RideRequest(
  id: 'in-1',
  isMine: false,
  status: RideRequestStatus.open,
  pickupAt: _now.add(const Duration(days: 1)),
  pickupLabel: 'Home',
  destinationName: 'Lincoln Elementary',
  kids: const [ChatKid(firstName: 'Ethan')],
  parent: const ChatPerson(firstName: 'Rachel', initials: 'RS'),
);

/// [MessagesRepository] with ride groups. [groupsDeployed] false = the
/// groups SQL isn't applied (every group call fails as not deployed).
class _GroupsRepository implements MessagesRepository {
  _GroupsRepository({this.groupsDeployed = true});

  bool groupsDeployed;
  int messageCalls = 0;
  int markReadCalls = 0;
  bool? mutedSet;
  String? renamedTo;
  List<String>? added;
  (String, List<String>, String?)? created;
  final List<GroupMessage> sent = [];

  RideGroupDetails details = const RideGroupDetails(
    id: 'g1',
    name: 'Home → Lincoln parents',
    schoolName: 'Lincoln Elementary',
    members: [
      RideGroupMember(
        id: 'ava-id',
        firstName: 'Ava',
        initials: 'AB',
        isOwner: true,
        kids: ['Mia'],
      ),
      RideGroupMember(
        id: _me,
        firstName: 'Vivek',
        initials: 'VK',
        isMe: true,
        kids: ['Emma', 'Noah'],
      ),
      RideGroupMember(id: 'ben-id', firstName: 'Ben', initials: 'BC'),
    ],
  );

  List<RideGroup> groups = [
    RideGroup(
      id: 'g1',
      name: 'Home → Lincoln parents',
      memberCount: 3,
      unread: 2,
      lastMessage: 'Ben: See you at 8',
      lastAt: _now.subtract(const Duration(minutes: 1)),
    ),
    RideGroup(
      id: 'g2',
      name: 'Swim carpool',
      memberCount: 4,
      muted: true,
      lastMessage: 'Ava created the group',
      lastAt: _now.subtract(const Duration(days: 3)),
    ),
  ];

  @override
  String? get myUserId => _me;

  @override
  bool get isSignedIn => true;

  @override
  Future<Either<Failure, RequestsInbox>> getRequestsInbox() async =>
      Right(RequestsInbox(incoming: [_incoming]));

  @override
  Future<Either<Failure, List<RideChat>>> getMyChats() async => Right([
    RideChat(
      requestId: 'in-1',
      driverId: _me,
      iAmDriver: true,
      status: RideRequestStatus.open,
      other: const ChatPerson(firstName: 'Rachel', initials: 'RS'),
      lastMessage: 'Thanks!',
      lastAt: _now.subtract(const Duration(hours: 2)),
      unread: 1,
    ),
  ]);

  Future<Either<Failure, T>> _group<T>(T Function() value) async =>
      groupsDeployed ? Right(value()) : const Left(_missing);

  @override
  Future<Either<Failure, List<RideGroup>>> getMyGroups() =>
      _group(() => groups);

  @override
  Future<Either<Failure, RideGroupDetails>> getGroup(String groupId) =>
      _group(() => details);

  @override
  Future<Either<Failure, List<GroupMessage>>> getGroupMessages(String groupId) {
    messageCalls++;
    return _group(
      () => [
        GroupMessage(
          id: 'm0',
          kind: GroupMessageKind.system,
          body: 'Ava created the group',
          createdAt: _now.subtract(const Duration(minutes: 10)),
        ),
        GroupMessage(
          id: 'm1',
          kind: GroupMessageKind.text,
          body: 'Who can drive Tuesday?',
          createdAt: _now.subtract(const Duration(minutes: 5)),
          sender: const GroupSender(
            id: 'ben-id',
            firstName: 'Ben',
            initials: 'BC',
          ),
        ),
        ...sent,
      ],
    );
  }

  @override
  Future<Either<Failure, GroupMessage>> sendGroupMessage({
    required String groupId,
    required String body,
  }) => _group(() {
    final m = GroupMessage(
      id: 's${sent.length}',
      kind: GroupMessageKind.text,
      body: body,
      createdAt: DateTime.now(),
      sender: const GroupSender(id: _me, firstName: 'Vivek', initials: 'VK'),
    );
    sent.add(m);
    return m;
  });

  @override
  Future<Either<Failure, Unit>> markGroupRead(String groupId) {
    markReadCalls++;
    return _group(() => unit);
  }

  @override
  Future<Either<Failure, String>> createGroup({
    required String name,
    required List<String> memberIds,
    String? schoolId,
  }) => _group(() {
    created = (name, memberIds, schoolId);
    return 'new-group';
  });

  @override
  Future<Either<Failure, int>> addGroupMembers({
    required String groupId,
    required List<String> memberIds,
  }) => _group(() {
    added = memberIds;
    return memberIds.length;
  });

  @override
  Future<Either<Failure, Unit>> leaveGroup(String groupId) =>
      _group(() => unit);

  @override
  Future<Either<Failure, Unit>> renameGroup({
    required String groupId,
    required String name,
  }) => _group(() {
    renamedTo = name;
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> setGroupMuted({
    required String groupId,
    required bool muted,
  }) => _group(() {
    mutedSet = muted;
    return unit;
  });

  @override
  Future<Either<Failure, List<RideGroupMember>>> getGroupCandidates(
    String? groupId,
  ) => _group(
    () => const [
      RideGroupMember(
        id: 'chloe-id',
        firstName: 'Chloe',
        initials: 'CD',
        kids: ['Leo'],
      ),
    ],
  );

  // Ride requests aren't used here.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MessagesProvider _messagesProvider(
  _GroupsRepository repo, {
  void Function(int)? onBadge,
}) => MessagesProvider(
  getRequestsInbox: GetRequestsInbox(repo),
  getMyChats: GetMyChats(repo),
  offerRide: OfferRide(repo),
  passRideRequest: PassRideRequest(repo),
  withdrawOffer: WithdrawOffer(repo),
  respondToOffer: RespondToOffer(repo),
  myUserId: () => repo.myUserId,
  getMyRideGroups: GetMyRideGroups(repo),
  onBadgeChanged: onBadge,
);

GroupChatProvider _chatProvider(_GroupsRepository repo) => GroupChatProvider(
  getRideGroup: GetRideGroup(repo),
  getGroupMessages: GetGroupMessages(repo),
  sendGroupMessage: SendGroupMessage(repo),
  markGroupRead: MarkGroupRead(repo),
);

Future<void> _register(_GroupsRepository repo) async {
  await sl.reset();
  sl
    ..registerFactory<MessagesProvider>(() => _messagesProvider(repo))
    ..registerFactory<GroupChatProvider>(() => _chatProvider(repo))
    ..registerFactory<GroupInfoProvider>(
      () => GroupInfoProvider(
        getRideGroup: GetRideGroup(repo),
        getGroupCandidates: GetGroupCandidates(repo),
        addGroupMembers: AddGroupMembers(repo),
        renameRideGroup: RenameRideGroup(repo),
        setGroupMuted: SetGroupMuted(repo),
        leaveRideGroup: LeaveRideGroup(repo),
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

/// Answers RPCs from [responses]; a missing name throws PostgREST's 404.
class _FakeApi extends ApiClient {
  _FakeApi(this.responses) : super(Dio());

  final Map<String, Object?> responses;
  final List<(String, Map<String, dynamic>?)> calls = [];

  @override
  Future<T> rpc<T>(
    String name, {
    required ResponseParser<T> parser,
    Map<String, dynamic>? params,
    bool skipAuth = false,
  }) async {
    calls.add((name, params));
    if (!responses.containsKey(name)) {
      throw const ServerException('Could not find the function', 404, null, {
        'code': 'PGRST202',
      });
    }
    return parser(responses[name]);
  }
}

/// Unused: families are set with `setFamilies`.
class _NoHome implements HomeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Family _family(String id, String schoolId, String school) => Family(
  id: id,
  parentName: id,
  initials: 'X',
  kids: [FamilyKid(firstName: 'Kid', schoolId: schoolId, schoolName: school)],
);

const _args = GroupChatArgs(groupId: 'g1', name: 'Home → Lincoln parents');

void main() {
  setUpAll(() async {
    final loader = FontLoader('HankenGrotesk');
    for (final w in [400, 500, 600, 700]) {
      final bytes = File('assets/fonts/HankenGrotesk-$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  group('JSON parsing', () {
    test('get_my_ride_groups rows, newest first, bad rows skipped', () {
      final groups = RideGroupModel.groupsFromJson([
        {
          'id': 'old',
          'name': 'Swim',
          'memberCount': 3,
          'unread': 0,
          'muted': true,
          'lastMessage': 'Ava left',
          'lastAt': '2026-11-01T08:00:00Z',
        },
        {'name': 'no id'},
        {
          'id': 'new',
          'name': 'Home → Lincoln parents',
          'memberCount': '6',
          'unread': 2,
          'muted': false,
          'lastMessage': 'Ben: See you at 8',
          'lastAt': '2026-11-09T08:00:00Z',
        },
      ]);
      expect(groups.map((g) => g.id), ['new', 'old']);
      expect(groups.first.memberCount, 6);
      expect(groups.first.hasUnread, isTrue);
      expect(groups.first.membersLabel, '6 members');
      expect(groups.last.muted, isTrue);
      expect(RideGroupModel.groupsFromJson('nope'), isEmpty);
    });

    test('get_ride_group details with members', () {
      final group = RideGroupModel.detailsFromJson({
        'id': 'g1',
        'name': 'Home → Lincoln parents',
        'schoolName': 'Lincoln Elementary',
        'muted': true,
        'maxMembers': 8,
        'members': [
          {
            'id': 'a',
            'firstName': 'Ava',
            'initials': 'AB',
            'role': 'owner',
            'isMe': false,
            'kids': ['Mia', 'Zoe'],
          },
          {
            'id': 'b',
            'firstName': 'Vivek',
            'initials': 'VK',
            'role': 'member',
            'isMe': true,
            'kids': <String>[],
          },
        ],
      })!;
      expect(group.schoolName, 'Lincoln Elementary');
      expect(group.muted, isTrue);
      expect(group.memberCount, 2);
      expect(group.remainingSlots, 6);
      expect(group.isFull, isFalse);
      expect(group.members.first.isOwner, isTrue);
      expect(group.members.first.kids, ['Mia', 'Zoe']);
      expect(group.members.last.isMe, isTrue);
      expect(RideGroupModel.detailsFromJson({'name': 'x'}), isNull);
    });

    test('messages: system lines have no sender, oldest first', () {
      final messages = RideGroupModel.messagesFromJson([
        {
          'id': 'm2',
          'kind': 'text',
          'body': 'Who can drive Tuesday?',
          'createdAt': '2026-11-09T08:05:00Z',
          'sender': {'id': 'ben', 'firstName': 'Ben', 'initials': 'BC'},
        },
        {
          'id': 'm1',
          'kind': 'system',
          'body': 'Vivek created the group',
          'createdAt': '2026-11-09T08:00:00Z',
          'sender': null,
        },
        {'id': 'bad'},
      ]);
      expect(messages.map((m) => m.id), ['m1', 'm2']);
      expect(messages.first.isSystem, isTrue);
      expect(messages.first.isMine('ben'), isFalse);
      expect(messages.last.isSystem, isFalse);
      expect(messages.last.sender?.firstName, 'Ben');
      expect(messages.last.isMine('ben'), isTrue);
      expect(RideGroupModel.idFromJson({'id': 'g9'}), 'g9');
    });
  });

  group('remote data source', () {
    test('sends camelCase params and parses results', () async {
      final api = _FakeApi({
        MessagesApiConstants.createRideGroup: {'id': 'g9'},
        MessagesApiConstants.getRideGroupMessages: <Object>[],
      });
      final remote = MessagesRemoteDataSourceImpl(api);
      final id = await remote.createGroup(
        name: 'Home → Lincoln',
        memberIds: ['a', 'b'],
      );
      expect(id, 'g9');
      expect(api.calls.first.$2, {
        'name': 'Home → Lincoln',
        'memberIds': ['a', 'b'],
      });
      await remote.getGroupMessages('g9');
      expect(api.calls.last.$2, {'groupId': 'g9'});
    });

    test('a missing RPC becomes groups_not_deployed', () async {
      final remote = MessagesRemoteDataSourceImpl(_FakeApi(const {}));
      expect(
        remote.getMyGroups(),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            MessagesApiConstants.groupsMissing,
          ),
        ),
      );
    });
  });

  group('MessagesProvider', () {
    test('merges groups and chats newest first; badge counts both', () async {
      final repo = _GroupsRepository();
      var badge = -1;
      final p = _messagesProvider(repo, onBadge: (n) => badge = n);
      await p.load();
      final order = [
        for (final item in p.items)
          switch (item) {
            RideChatItem(:final chat) => chat.other.firstName,
            RideGroupItem(:final group) => group.name,
          },
      ];
      expect(order, ['Home → Lincoln parents', 'Rachel', 'Swim carpool']);
      // 1 chat + 1 group with unread messages.
      expect(p.chatsBadge, 2);
      // + 1 request waiting for an answer.
      expect(badge, 3);

      p.search('swim');
      expect(p.items, hasLength(1));
      p.dispose();
    });

    test('groups not deployed: only chats, no error', () async {
      final repo = _GroupsRepository(groupsDeployed: false);
      final p = _messagesProvider(repo);
      await p.load();
      expect(p.items, hasLength(1));
      expect(p.chatsError, isNull);
      expect(p.chatsBadge, 1);
      p.dispose();
    });

    test('badge counter adds group unread; failure counts as 0', () async {
      final repo = _GroupsRepository();
      final badges = NavBadges.instance;
      final counter = MessagesBadgeCounter(
        getRequestsInbox: GetRequestsInbox(repo),
        getMyChats: GetMyChats(repo),
        getMyRideGroups: GetMyRideGroups(repo),
      );
      await counter();
      expect(badges.messages.value, 3);
      repo.groupsDeployed = false;
      await counter();
      expect(badges.messages.value, 2);
    });
  });

  group('GroupChatProvider', () {
    test('opens, marks read, parses system lines and sends', () async {
      final repo = _GroupsRepository();
      final p = _chatProvider(repo);
      await p.open(_args);
      expect(p.title, 'Home → Lincoln parents');
      expect(p.subtitle, '3 members');
      expect(p.messages.first.isSystem, isTrue);
      expect(p.isMine(p.messages.last), isFalse);
      expect(repo.markReadCalls, 1);

      expect(await p.send('  I can drive  '), isNull);
      expect(p.messages.last.body, 'I can drive');
      expect(p.isMine(p.messages.last), isTrue);

      // Nothing new since: no second mark-read.
      await p.refreshMessages();
      expect(repo.markReadCalls, 1);
      p.dispose();
    });

    test('not deployed: unavailable and polling stops', () async {
      final repo = _GroupsRepository(groupsDeployed: false);
      final p = _chatProvider(repo);
      await p.open(_args);
      p.startPolling();
      expect(p.unavailable, isTrue);
      expect(p.isPolling, isFalse);
      expect(await p.send('hi'), MessagesApiConstants.groupsMissingMessage);
      p.dispose();
    });
  });

  group('screens', () {
    for (final size in const [Size(390, 844), Size(320, 568)]) {
      final tag = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('Chats tab lists groups with chats at $tag', (tester) async {
        await _register(_GroupsRepository());
        await _pump(tester, const MessagesScreen(), size: size);
        expect(find.text('Home → Lincoln parents'), findsOneWidget);
        expect(find.text('Ben: See you at 8'), findsOneWidget);
        expect(find.text('Swim carpool'), findsOneWidget);
        expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
        expect(find.text('Rachel'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _dispose(tester);
      });

      testWidgets('group chat renders, polls and sends at $tag', (
        tester,
      ) async {
        final repo = _GroupsRepository();
        await _register(repo);
        await _pump(tester, const GroupChatScreen(), arguments: _args);
        expect(find.text('Home → Lincoln parents'), findsOneWidget);
        expect(find.text('3 members'), findsOneWidget);
        expect(find.text('Ava created the group'), findsOneWidget);
        expect(find.text('Ben'), findsOneWidget);
        expect(find.text('BC'), findsOneWidget);
        final calls = repo.messageCalls;
        await tester.pump(MessagesApiConstants.threadPollInterval);
        expect(repo.messageCalls, greaterThan(calls));

        await tester.enterText(find.byType(TextField), 'I can drive');
        await tester.tap(find.bySemanticsLabel('Send'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('I can drive'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _dispose(tester);
      });

      testWidgets('group info renders members and actions at $tag', (
        tester,
      ) async {
        final repo = _GroupsRepository();
        await _register(repo);
        await _pump(tester, const GroupInfoScreen(), arguments: _args);
        expect(find.text('Home → Lincoln parents'), findsOneWidget);
        expect(find.text('Lincoln Elementary · 3 members'), findsOneWidget);
        expect(find.text('Owner'), findsOneWidget);
        expect(find.text('You'), findsOneWidget);
        expect(find.text('Parent of Emma & Noah'), findsOneWidget);
        expect(find.text('Add parents'), findsOneWidget);

        await tester.tap(find.byType(AppToggle));
        await tester.pump();
        expect(repo.mutedSet, isTrue);
        expect(tester.takeException(), isNull);
        await _dispose(tester);
      });
    }

    testWidgets('add parents picks a candidate', (tester) async {
      final repo = _GroupsRepository();
      await _register(repo);
      await _pump(tester, const GroupInfoScreen(), arguments: _args);
      await tester.tap(find.text('Add parents'));
      await tester.pumpAndSettle();
      expect(find.text('Chloe'), findsOneWidget);
      await tester.tap(find.text('Chloe'));
      await tester.pump();
      await tester.tap(find.text('Add 1 parent'));
      await tester.pumpAndSettle();
      expect(repo.added, ['chloe-id']);
      expect(tester.takeException(), isNull);
      await _dispose(tester);
    });

    testWidgets('full group disables Add parents', (tester) async {
      final repo = _GroupsRepository()
        ..details = RideGroupDetails(
          id: 'g1',
          name: 'Full',
          maxMembers: 2,
          members: const [
            RideGroupMember(id: 'a', firstName: 'Ava', initials: 'A'),
            RideGroupMember(id: 'b', firstName: 'Ben', initials: 'B'),
          ],
        );
      await _register(repo);
      await _pump(tester, const GroupInfoScreen(), arguments: _args);
      expect(find.text('Groups can have up to 2 families'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('groups not deployed: Chats tab quiet, group screen says so', (
      tester,
    ) async {
      final repo = _GroupsRepository(groupsDeployed: false);
      await _register(repo);
      await _pump(tester, const MessagesScreen());
      expect(find.text('Rachel'), findsOneWidget);
      expect(find.textContaining('Group chats'), findsNothing);
      await _dispose(tester);

      await _pump(tester, const GroupChatScreen(), arguments: _args);
      expect(find.text(MessagesApiConstants.groupsMissingMessage), findsOne);
      final calls = repo.messageCalls;
      await tester.pump(MessagesApiConstants.threadPollInterval * 3);
      expect(repo.messageCalls, calls);
      expect(tester.takeException(), isNull);
      await _dispose(tester);
    });
  });

  group('Start a group (Families near you)', () {
    FamiliesNearYouProvider provider(_GroupsRepository repo) =>
        FamiliesNearYouProvider(
          getFamiliesNearMe: GetFamiliesNearMe(_NoHome()),
          createRideGroup: CreateRideGroup(repo),
        )..setFamilies([
          _family('ava', 'lincoln', 'Lincoln Elementary'),
          _family('ben', 'lincoln', 'Lincoln Elementary'),
          _family('dev', 'swim', 'Bluewave Swim'),
        ]);

    test('names the group after the shared school and creates it', () async {
      final repo = _GroupsRepository();
      final p = provider(repo);
      expect(p.canStartGroup, isFalse);
      p.beginSelection(p.families[0]);
      p.toggle(p.families[1]);
      expect(p.canStartGroup, isTrue);
      expect(p.suggestedGroupName, 'Home → Lincoln Elementary');
      final (id, error) = await p.startGroup('Home → Lincoln');
      expect((id, error), ('new-group', null));
      expect(repo.created?.$1, 'Home → Lincoln');
      expect(repo.created?.$2, ['ava', 'ben']);
      expect(repo.created?.$3, 'lincoln');
    });

    test('no shared school: generic name, no school id', () async {
      final repo = _GroupsRepository();
      final p = provider(repo)..beginSelection(_family('ava', 'l', 'L'));
      p.toggle(p.families[2]);
      expect(p.suggestedGroupName, 'Our ride group');
      await p.startGroup('Our ride group');
      expect(repo.created?.$3, isNull);
    });

    test('more than 7 families hides it; not deployed says so', () async {
      final repo = _GroupsRepository(groupsDeployed: false);
      final p = FamiliesNearYouProvider(
        getFamiliesNearMe: GetFamiliesNearMe(_NoHome()),
        createRideGroup: CreateRideGroup(repo),
      )..setFamilies([for (var i = 0; i < 8; i++) _family('f$i', 's', 'S')]);
      p.beginSelection(p.families.first);
      p.toggleAllVisible();
      expect(p.selectedCount, 8);
      expect(p.canStartGroup, isFalse);
      p.toggle(p.families.first);
      final (id, error) = await p.startGroup('S');
      expect(id, isNull);
      expect(error, MessagesApiConstants.groupsMissingMessage);
    });
  });

  test('NoParams use case returns repository groups', () async {
    final groups = await GetMyRideGroups(_GroupsRepository())(const NoParams());
    expect(groups.getRight().toNullable(), hasLength(2));
  });
}
