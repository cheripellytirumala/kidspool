import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/common/presentation/state/live_refresh.dart';

void main() {
  testWidgets('a tick reloads the screen on top, not a covered one', (
    tester,
  ) async {
    var home = 0;
    var detail = 0;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: LiveRefreshListener(
          onRefresh: () async => home++,
          child: const Text('home'),
        ),
      ),
    );
    LiveRefresh.instance.nudge();
    await tester.pump();
    expect(home, 1);

    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => LiveRefreshListener(
          onRefresh: () async => detail++,
          child: const Text('detail'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    LiveRefresh.instance.nudge();
    await tester.pump();
    expect((home, detail), (1, 1));

    // Gone from the tree: no more calls.
    await tester.pumpWidget(const SizedBox());
    LiveRefresh.instance.nudge();
    await tester.pump();
    expect((home, detail), (1, 1));
  });
}
