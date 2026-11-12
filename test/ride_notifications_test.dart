import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/messages/presentation/screens/ride_request_detail_screen.dart';
import 'package:fpdart/fpdart.dart';
import 'package:kidspool/common/core/error/exceptions.dart';
import 'package:kidspool/common/core/error/failures.dart';
import 'package:kidspool/common/core/network/api_client.dart';
import 'package:kidspool/common/core/router/app_routes.dart';
import 'package:kidspool/notifications/core/constants/notifications_api_constants.dart';
import 'package:kidspool/notifications/core/services/local_notifications.dart';
import 'package:kidspool/notifications/core/services/push_messaging.dart';
import 'package:kidspool/notifications/core/services/ride_notifications.dart';
import 'package:kidspool/notifications/data/data_sources/remote/push_tokens_remote_data_source.dart';
import 'package:kidspool/notifications/data/repositories/push_tokens_repository_impl.dart';
import 'package:kidspool/notifications/domain/repositories/push_tokens_repository.dart';
import 'package:kidspool/ride_tracking/core/utils/ride_alert_payload.dart';
import 'package:kidspool/ride_tracking/domain/entities/ride_alert.dart';
import 'package:kidspool/ride_tracking/domain/repositories/ride_alert_notifier.dart';
import 'package:kidspool/ride_tracking/domain/repositories/ride_alerts_repository.dart';
import 'package:kidspool/ride_tracking/domain/usecases/get_ride_alerts.dart';
import 'package:kidspool/ride_tracking/presentation/providers/ride_alerts_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RideAlertPayload', () {
    test('encodes and decodes a local notification payload', () {
      const payload = RideAlertPayload(
        kind: RideAlertKind.started,
        requestId: 'r1',
      );
      final text = payload.encode();
      expect(text, contains('"kind":"ride_started"'));
      expect(RideAlertPayload.decode(text), payload);
      const arrived = RideAlertPayload(
        kind: RideAlertKind.arrived,
        requestId: 'r2',
      );
      expect(RideAlertPayload.decode(arrived.encode()), arrived);
    });

    test('ignores payloads that are not ride alerts', () {
      expect(RideAlertPayload.decode(null), isNull);
      expect(RideAlertPayload.decode(''), isNull);
      expect(RideAlertPayload.decode('not json'), isNull);
      expect(RideAlertPayload.decode('[1]'), isNull);
      expect(
        RideAlertPayload.decode('{"kind":"ride_request","requestId":"x"}'),
        isNull,
      );
      expect(RideAlertPayload.decode('{"kind":"ride_started"}'), isNull);
    });

    test('reads a push data map', () {
      // S20's feed / push kind (regression: it used to map to nothing).
      expect(RideAlertKind.fromValue('ride_arrived'), RideAlertKind.arrived);
      expect(
        RideAlertPayload.fromData({'kind': 'ride_arrived', 'requestId': 'r9'}),
        const RideAlertPayload(kind: RideAlertKind.arrived, requestId: 'r9'),
      );
      expect(RideAlertPayload.fromData({'kind': 'ride_arrived'}), isNull);
    });

    test('routes S19 to live tracking and S20 to the ride summary', () {
      const started = RideAlertPayload(
        kind: RideAlertKind.started,
        requestId: 'a',
      );
      const arrived = RideAlertPayload(
        kind: RideAlertKind.arrived,
        requestId: 'b',
      );
      expect(started.route, AppRoutes.liveTracking);
      expect(arrived.route, AppRoutes.rideCompleted);
      expect((arrived.arguments as RideArgs).requestId, 'b');
    });

    test('accepted opens the ride details (and round-trips)', () {
      expect(RideAlertKind.fromValue('ride_confirmed'), RideAlertKind.accepted);
      const accepted = RideAlertPayload(
        kind: RideAlertKind.accepted,
        requestId: 'c',
      );
      expect(accepted.route, AppRoutes.rideRequestDetail);
      final args = accepted.arguments as RideRequestArgs;
      expect((args.requestId, args.isMine), ('c', true));
      expect(RideAlertPayload.decode(accepted.encode()), accepted);
    });

    test('fromAlert needs a ride id', () {
      expect(RideAlertPayload.fromAlert(_alert('x', requestId: null)), isNull);
      expect(
        RideAlertPayload.fromAlert(_alert('x', requestId: 'r')),
        const RideAlertPayload(kind: RideAlertKind.started, requestId: 'r'),
      );
    });

    test('notification ids match the send-ride-push Edge Function', () {
      // Reference values from the function's notificationId() (JS).
      expect(
        RideAlertNotificationId.of(
          'ride_started:6f1c2a7e-0000-4000-8000-000000000001',
        ),
        2090356391,
      );
      expect(RideAlertNotificationId.of('ride_arrived:abc'), 374359495);
      expect(RideAlertNotificationId.of(''), 18652613);
    });
  });

  group('RideAlertsProvider + notifier', () {
    test('posts one system notification per new alert', () async {
      final now = DateTime(2026, 11, 10, 8);
      final repo = _FakeAlertsRepository([
        _alert('ride_started:a', createdAt: now),
      ]);
      final notifier = _FakeNotifier();
      final provider = RideAlertsProvider(
        getRideAlerts: GetRideAlerts(repo),
        notifier: notifier,
        clock: () => now,
      );
      await provider.check();
      await provider.check();
      expect(notifier.shown.map((a) => a.id), ['ride_started:a']);

      repo.alerts = [
        _alert('ride_arrived:a', createdAt: now),
        _alert('ride_started:a', createdAt: now),
      ];
      await provider.check();
      expect(notifier.shown.map((a) => a.id), [
        'ride_started:a',
        'ride_arrived:a',
      ]);
      provider.dispose();
    });

    test('stale alerts are neither queued nor posted', () async {
      final now = DateTime(2026, 11, 10, 8);
      final notifier = _FakeNotifier();
      final provider = RideAlertsProvider(
        getRideAlerts: GetRideAlerts(
          _FakeAlertsRepository([
            _alert('old', createdAt: now.subtract(const Duration(hours: 1))),
          ]),
        ),
        notifier: notifier,
        clock: () => now,
      );
      await provider.check();
      expect(provider.current, isNull);
      expect(notifier.shown, isEmpty);
      provider.dispose();
    });

    test('a foreground push re-reads the feed right away', () async {
      final now = DateTime(2026, 11, 10, 8);
      final repo = _FakeAlertsRepository([]);
      final notifier = _FakeNotifier();
      final provider = RideAlertsProvider(
        getRideAlerts: GetRideAlerts(repo),
        notifier: notifier,
        clock: () => now,
      );
      repo.alerts = [_alert('ride_started:z', createdAt: now)];
      notifier.pushes.add(null);
      await pumpEventQueue();
      expect(repo.calls, 1);
      expect(provider.current?.id, 'ride_started:z');
      provider.dispose();
    });
  });

  group('RideNotifications', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    RideNotifications build({
      required _FakePush push,
      PushTokensRepository? tokens,
      _FakeLocal? local,
      bool signedIn = true,
    }) => RideNotifications(
      local: local ?? _FakeLocal(),
      push: push,
      tokens: tokens ?? _FakeTokens(),
      preferences: prefs,
      isSignedIn: () => signedIn,
      platform: NotificationsApiConstants.platformIos,
    );

    test('without Firebase config, no token is registered', () async {
      final tokens = _FakeTokens();
      final local = _FakeLocal();
      final notifications = build(
        push: _FakePush(configured: false),
        tokens: tokens,
        local: local,
      );
      await notifications.init(navigatorKey: GlobalKey<NavigatorState>());
      await notifications.onHomeShown();
      expect(tokens.registered, isEmpty);
      // Local notifications still work and permission is asked once.
      expect(local.permissionRequests, 1);
      await notifications.onHomeShown();
      expect(local.permissionRequests, 1);
    });

    test('with Firebase, registers the token once and unregisters it on '
        'sign-out', () async {
      final tokens = _FakeTokens();
      final push = _FakePush(configured: true, token: 'fcm-1');
      final notifications = build(push: push, tokens: tokens);
      await notifications.init(navigatorKey: GlobalKey<NavigatorState>());
      await notifications.onHomeShown();
      await notifications.onHomeShown();
      expect(tokens.registered, ['fcm-1:ios']);
      expect(push.permissionRequests, 1);

      await notifications.onSignOut();
      expect(tokens.unregistered, ['fcm-1']);
      expect(notifications.registeredToken, isNull);
    });

    test('signed out: nothing is registered', () async {
      final tokens = _FakeTokens();
      final notifications = build(
        push: _FakePush(configured: true, token: 't'),
        tokens: tokens,
        signedIn: false,
      );
      await notifications.init(navigatorKey: GlobalKey<NavigatorState>());
      await notifications.onHomeShown();
      expect(tokens.registered, isEmpty);
    });

    test('a missing register_push_token RPC (404) fails silently', () async {
      final api = _MissingRpcApiClient();
      final repo = PushTokensRepositoryImpl(
        remoteDataSource: PushTokensRemoteDataSourceImpl(api),
      );
      expect(
        await repo.register(token: 't', platform: 'ios'),
        const Right<Failure, bool>(false),
      );
      final notifications = build(
        push: _FakePush(configured: true, token: 't'),
        tokens: repo,
      );
      await notifications.init(navigatorKey: GlobalKey<NavigatorState>());
      await notifications.onHomeShown();
      await notifications.registerPushToken('t2');
      expect(notifications.registeredToken, isNull);
      // No retries once the backend says it doesn't have the RPC.
      expect(api.calls, 2);
      await notifications.onSignOut();
      expect(api.calls, 2);
    });

    testWidgets('a tap before Home waits, then opens the ride', (tester) async {
      final key = GlobalKey<NavigatorState>();
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          onGenerateRoute: (settings) {
            final args = settings.arguments;
            if (args is RideArgs) {
              opened.add('${settings.name}:${args.requestId}');
            }
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const SizedBox(),
            );
          },
        ),
      );
      final local = _FakeLocal(
        launch: const RideAlertPayload(
          kind: RideAlertKind.arrived,
          requestId: 'r1',
        ),
      );
      final notifications = build(
        push: _FakePush(configured: false),
        local: local,
      );
      await tester.runAsync(() => notifications.init(navigatorKey: key));
      expect(notifications.pending?.requestId, 'r1');
      expect(opened, isEmpty);

      await tester.runAsync(notifications.onHomeShown);
      await tester.pumpAndSettle();
      expect(opened, ['${AppRoutes.rideCompleted}:r1']);
      expect(notifications.pending, isNull);

      // Once on Home, a tap opens right away.
      local.onTap!(
        const RideAlertPayload(kind: RideAlertKind.started, requestId: 'r2'),
      );
      await tester.pumpAndSettle();
      expect(opened.last, '${AppRoutes.liveTracking}:r2');
    });

    test('show() is a no-op until local notifications are set up', () async {
      final local = _FakeLocal();
      final notifications = build(
        push: _FakePush(configured: false),
        local: local,
      );
      await notifications.show(_alert('a'));
      expect(local.shown, isEmpty);
      await notifications.init(navigatorKey: GlobalKey<NavigatorState>());
      await notifications.show(_alert('a'));
      expect(local.shown, ['a']);
    });
  });
  group('drive reminders (30 min before)', () {
    test(
      'scheduled ahead, shown now once when late, cancelled when gone',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final local = _FakeLocal();
        final n = RideNotifications(
          local: local,
          push: _FakePush(configured: false),
          tokens: _FakeTokens(),
          preferences: prefs,
          isSignedIn: () => true,
        );
        await n.init(navigatorKey: GlobalKey<NavigatorState>());
        final now = DateTime(2026, 11, 12, 7, 0);
        DriveReminder drive(String id, int minutesAway) => DriveReminder(
          requestId: id,
          pickupAt: now.add(Duration(minutes: minutesAway)),
          kids: 'Emma',
          destination: 'Doon Public School',
        );

        await n.syncDriveReminders([
          drive('far', 90),
          drive('soon', 10),
        ], now: now);
        expect(
          local.reminders['far']!.$1,
          now.add(const Duration(minutes: 60)),
        );
        expect(local.reminders['far']!.$2, 'Ride in 30 minutes 🚗');
        expect(local.reminders['soon']!.$2, 'Ride in 10 minutes 🚗');

        // Next sync: "soon" isn't shown again; "far" was cancelled/started.
        local.reminders.clear();
        await n.syncDriveReminders([drive('soon', 9)], now: now);
        expect(local.reminders, isEmpty);
        expect(drive('x', 30).body, contains('Please make sure you start'));
      },
    );
  });
}

RideAlert _alert(
  String id, {
  String? requestId = 'r',
  RideAlertKind kind = RideAlertKind.started,
  DateTime? createdAt,
}) => RideAlert(
  id: id,
  kind: kind,
  title: 'Ride started 🚗',
  requestId: requestId,
  createdAt: createdAt ?? DateTime(2026, 11, 10, 8),
);

class _FakeAlertsRepository implements RideAlertsRepository {
  _FakeAlertsRepository(this.alerts);

  List<RideAlert> alerts;
  int calls = 0;

  @override
  bool get isSignedIn => true;

  @override
  Future<Either<Failure, List<RideAlert>>> getRideAlerts() async {
    calls++;
    return Right(alerts);
  }
}

class _FakeNotifier implements RideAlertNotifier {
  final shown = <RideAlert>[];
  final pushes = StreamController<void>.broadcast();

  @override
  Future<void> show(RideAlert alert) async => shown.add(alert);

  @override
  Stream<void> get pushReceived => pushes.stream;
}

class _FakeLocal implements LocalNotifications {
  _FakeLocal({this.launch});

  final RideAlertPayload? launch;
  RideAlertTapCallback? onTap;
  int permissionRequests = 0;
  final shown = <String>[];

  @override
  Future<void> init({required RideAlertTapCallback onTap}) async =>
      this.onTap = onTap;

  @override
  Future<RideAlertPayload?> launchPayload() async => launch;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<void> showRideAlert(RideAlert alert) async => shown.add(alert.id);

  /// requestId → (when, title).
  final reminders = <String, (DateTime, String)>{};

  @override
  Future<void> scheduleRideReminder({
    required String requestId,
    required DateTime at,
    required String title,
    required String body,
  }) async => reminders[requestId] = (at, title);

  @override
  Future<void> cancelRideReminder(String requestId) async =>
      reminders.remove(requestId);
}

class _FakePush implements PushMessaging {
  _FakePush({required this.configured, this.token});

  final bool configured;
  final String? token;
  bool _available = false;
  int permissionRequests = 0;

  @override
  Future<bool> init() async => _available = configured;

  @override
  bool get isAvailable => _available;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<String?> getToken() async => _available ? token : null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onMessage => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onMessageOpenedApp => const Stream.empty();

  @override
  Future<Map<String, dynamic>?> getInitialMessage() async => null;
}

class _FakeTokens implements PushTokensRepository {
  final registered = <String>[];
  final unregistered = <String>[];

  @override
  Future<Either<Failure, bool>> register({
    required String token,
    required String platform,
  }) async {
    registered.add('$token:$platform');
    return const Right(true);
  }

  @override
  Future<Either<Failure, bool>> unregister(String token) async {
    unregistered.add(token);
    return const Right(true);
  }
}

/// PostgREST before the SQL is applied: 404 `PGRST202`.
class _MissingRpcApiClient extends ApiClient {
  _MissingRpcApiClient() : super(Dio());

  int calls = 0;

  @override
  Future<T> rpc<T>(
    String name, {
    required ResponseParser<T> parser,
    Map<String, dynamic>? params,
    bool skipAuth = false,
  }) async {
    calls++;
    throw const ServerException('Not found', 404, 'PGRST202');
  }
}
