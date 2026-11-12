import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/messages/data/data_sources/local/passed_requests_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('passed requests survive a restart (new store, same prefs)', () async {
    final prefs = await SharedPreferences.getInstance();
    await PassedRequestsStore(prefs).add('vivek', 'r1');
    await PassedRequestsStore(prefs).add('vivek', 'r2');
    expect(PassedRequestsStore(prefs).read('vivek'), {'r1', 'r2'});
  });

  test('kept per parent; signed out reads nothing', () async {
    final store = PassedRequestsStore(await SharedPreferences.getInstance());
    await store.add('vivek', 'r1');
    expect(store.read('jessie'), isEmpty);
    expect(store.read(null), isEmpty);
    await store.add(null, 'r9');
    expect(store.read('vivek'), {'r1'});
  });

  test('keeps only the newest ids', () async {
    final store = PassedRequestsStore(await SharedPreferences.getInstance());
    for (var i = 0; i < PassedRequestsStore.maxKept + 3; i++) {
      await store.add('vivek', 'r$i');
    }
    final ids = store.read('vivek');
    expect(ids.length, PassedRequestsStore.maxKept);
    expect(ids.contains('r0'), isFalse);
    expect(ids.contains('r${PassedRequestsStore.maxKept + 2}'), isTrue);
  });
}
