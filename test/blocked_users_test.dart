import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/common/core/error/failures.dart';
import 'package:kidspool/safety/core/safety_api_constants.dart';
import 'package:kidspool/safety/domain/safety_entities.dart';
import 'package:kidspool/safety/presentation/blocked_users.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_safety.dart';

void main() {
  late FakeSafetyRepository repo;
  late SharedPreferences prefs;
  var me = 'me';

  BlockedUsers make() =>
      BlockedUsers(repository: repo, preferences: prefs, userId: () => me);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = FakeSafetyRepository();
    me = 'me';
  });

  const jen = BlockedUser(id: 'jen', name: 'Jen', initials: 'JP');

  test(
    'block hides at once, is sent to the server and kept per user',
    () async {
      final blocked = make();
      var notified = 0;
      blocked.addListener(() => notified++);
      expect(await blocked.block(jen), isNull);
      expect(blocked.isBlocked('jen'), isTrue);
      expect(repo.blocked, ['jen']);
      expect(notified, greaterThan(0));

      // Same account on a fresh start: still blocked (server list too).
      repo.serverBlocks = const [jen];
      expect(make().isBlocked('jen'), isTrue);
      // Another account on this phone: not blocked.
      me = 'someone-else';
      expect(make().isBlocked('jen'), isFalse);
    },
  );

  test('unblock removes it', () async {
    final blocked = make();
    await blocked.block(jen);
    expect(await blocked.unblock('jen'), isNull);
    expect(blocked.isBlocked('jen'), isFalse);
    expect(repo.blocked, isEmpty);
  });

  test(
    'before the SQL is applied, blocking still works on this phone',
    () async {
      repo.failWith = const ServerFailure(
        'This isn’t available yet.',
        code: SafetyApiConstants.functionNotFound,
      );
      final blocked = make();
      expect(await blocked.block(jen), isNull);
      expect(blocked.isBlocked('jen'), isTrue);
    },
  );

  test('load takes the server list', () async {
    repo.serverBlocks = const [jen];
    final blocked = make();
    await blocked.load();
    expect(blocked.users, [jen]);
    expect(blocked.isBlocked('jen'), isTrue);
  });
}
