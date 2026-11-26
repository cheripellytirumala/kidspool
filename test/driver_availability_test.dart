import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:kidspool/common/core/di/injection_container.dart';
import 'package:kidspool/common/core/error/failures.dart';
import 'package:kidspool/home/domain/repositories/driver_availability_repository.dart';
import 'package:kidspool/home/domain/usecases/get_driver_available.dart';
import 'package:kidspool/home/domain/usecases/set_driver_available.dart';
import 'package:kidspool/home/presentation/providers/driver_availability_provider.dart';
import 'package:kidspool/home/presentation/widgets/home_header_controls.dart';

class _Repo implements DriverAvailabilityRepository {
  final calls = <bool>[];
  bool fail = false;

  /// What `get_driver_available` answers (null: no answer).
  bool? server = false;
  int reads = 0;

  @override
  Future<Either<Failure, bool>> getAvailable() async {
    reads++;
    final value = server;
    if (value == null) return const Left(ServerFailure('No connection.'));
    return Right(value);
  }

  @override
  Future<Either<Failure, bool>> setAvailable(bool available) async {
    calls.add(available);
    if (fail) return const Left(ServerFailure('No connection.'));
    return Right(available);
  }
}

DriverAvailabilityProvider _provider(_Repo repo, {Duration? heartbeat}) =>
    DriverAvailabilityProvider(
      setDriverAvailable: SetDriverAvailable(repo),
      getDriverAvailable: GetDriverAvailable(repo),
      heartbeat: heartbeat ?? const Duration(hours: 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('opening the app shows the server\'s Off and writes nothing', () async {
    final repo = _Repo();
    final p = _provider(repo);
    await p.sync(isDriver: true);
    expect(p.available, isFalse);
    expect(repo.calls, isEmpty);
    await p.sync(isDriver: true); // later Home visits don't read again
    expect(repo.reads, 1);
    p.dispose();
  });

  test('opening the app shows the server\'s On and keeps it fresh', () async {
    final repo = _Repo()..server = true;
    final p = _provider(repo);
    await p.sync(isDriver: true);
    expect(p.available, isTrue);
    expect(repo.calls, [true]); // "still on"
    p.dispose();
  });

  test('no answer from the server: stays Off, nothing written', () async {
    final repo = _Repo()..server = null;
    final p = _provider(repo);
    await p.sync(isDriver: true);
    expect(p.available, isFalse);
    expect(repo.calls, isEmpty);
    p.dispose();
  });

  test('not a driver: the server is not asked', () async {
    final repo = _Repo()..server = true;
    final p = _provider(repo);
    await p.sync(isDriver: false);
    expect(p.available, isFalse);
    expect(repo.reads, 0);
    p.dispose();
  });

  test('switched off on another phone: Off when back in the app', () async {
    final repo = _Repo();
    final p = _provider(repo);
    await p.sync(isDriver: true);
    await p.setAvailable(true);
    repo.server = false;
    p.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(p.available, isFalse);
    expect(repo.calls, [true]); // no "still on" ping
    p.dispose();
  });

  test(
    'on stays on in the background, comes back on in the foreground',
    () async {
      final repo = _Repo();
      final p = _provider(repo);
      await p.sync(isDriver: true);
      expect(await p.setAvailable(true), isNull);
      expect(p.available, isTrue);

      p.didChangeAppLifecycleState(AppLifecycleState.inactive);
      p.didChangeAppLifecycleState(AppLifecycleState.hidden);
      p.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(p.available, isTrue);
      expect(repo.calls, [true]);

      repo.server = true;
      p.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(p.available, isTrue);
      expect(repo.calls, [true, true]); // "still on"
      p.dispose();
    },
  );

  test('app closing turns it off', () async {
    final repo = _Repo();
    final p = _provider(repo);
    await p.sync(isDriver: true);
    await p.setAvailable(true);
    p.didChangeAppLifecycleState(AppLifecycleState.detached);
    expect(p.available, isFalse);
    expect(repo.calls.last, isFalse);
    p.dispose();
  });

  test('switching off, and a failed switch goes back', () async {
    final repo = _Repo();
    final p = _provider(repo);
    await p.sync(isDriver: true);
    await p.setAvailable(true);
    await p.setAvailable(false);
    expect(p.available, isFalse);
    expect(repo.calls.last, isFalse);

    repo.fail = true;
    expect(await p.setAvailable(true), 'No connection.');
    expect(p.available, isFalse);
    p.dispose();
  });

  test('a user who stops giving rides is switched off; sign-out too', () async {
    final repo = _Repo();
    final p = _provider(repo);
    await p.sync(isDriver: true);
    await p.setAvailable(true);
    await p.sync(isDriver: false);
    expect(p.available, isFalse);

    await p.setAvailable(true);
    await p.turnOff();
    expect(p.available, isFalse);
    expect(repo.calls.last, isFalse);
    p.dispose();
  });

  testWidgets('heartbeat while on', (tester) async {
    final repo = _Repo();
    final p = _provider(repo, heartbeat: const Duration(minutes: 5));
    await p.sync(isDriver: true);
    await p.setAvailable(true);
    await tester.pump(const Duration(minutes: 11));
    expect(repo.calls, [true, true, true]);
    await p.setAvailable(false);
    await tester.pump(const Duration(minutes: 11));
    expect(repo.calls, [true, true, true, false]);
    p.dispose();
  });

  testWidgets('menu: Notifications and Log out in the dropdown', (
    tester,
  ) async {
    var notifications = 0;
    var logOut = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: HomeMenuButton(
              hasUnseenNotifications: true,
              onNotifications: () => notifications++,
              onLogOut: () => logOut++,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Notifications'), findsNothing);
    expect(find.byIcon(Icons.power_settings_new_rounded), findsNothing);

    await tester.tap(find.byType(HomeMenuButton));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(notifications, 1);

    await tester.tap(find.byType(HomeMenuButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(logOut, 1);
  });

  testWidgets('Available switch turns the driver on and off', (tester) async {
    final repo = _Repo();
    final p = _provider(repo);
    sl.registerSingleton<DriverAvailabilityProvider>(p);
    addTearDown(() => sl.unregister<DriverAvailabilityProvider>());
    await p.sync(isDriver: true);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: AvailabilitySwitch())),
      ),
    );
    expect(find.text('Off'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Available'), findsOneWidget);
    expect(repo.calls.last, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);
    expect(repo.calls.last, isFalse);
  });
}
