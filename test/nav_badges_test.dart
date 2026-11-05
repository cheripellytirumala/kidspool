import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/common/presentation/state/nav_badges.dart';
import 'package:kidspool/common/presentation/widgets/app_bottom_nav.dart';

Widget _bar() => const MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: AppBottomNav(current: AppTab.home),
    ),
  ),
);

void main() {
  tearDown(NavBadges.instance.clear);

  testWidgets('Messages tab shows the unread count, hidden at 0', (
    tester,
  ) async {
    await tester.pumpWidget(_bar());
    expect(find.text('3'), findsNothing);

    NavBadges.instance.setMessages(3);
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    expect(find.bySemanticsLabel('Messages, 3 new'), findsOneWidget);

    NavBadges.instance.setMessages(120);
    await tester.pump();
    expect(find.text('99+'), findsOneWidget);

    NavBadges.instance.setMessages(0);
    await tester.pump();
    expect(find.text('0'), findsNothing);
  });

  test('refresh recounts, but not again within the throttle window', () async {
    var calls = 0;
    NavBadges.instance.registerMessagesCounter(() async {
      calls++;
      NavBadges.instance.setMessages(2);
    });

    await NavBadges.instance.refresh();
    await NavBadges.instance.refresh();
    expect(calls, 1);
    expect(NavBadges.instance.messages.value, 2);

    await NavBadges.instance.refresh(force: true);
    expect(calls, 2);

    NavBadges.instance.clear();
    expect(NavBadges.instance.messages.value, 0);
    await NavBadges.instance.refresh();
    expect(calls, 3);
  });
}
