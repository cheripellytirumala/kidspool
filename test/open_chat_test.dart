import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/common/core/router/app_routes.dart';
import 'package:kidspool/common/core/router/open_chat.dart';

void main() {
  testWidgets('Back from a chat opened at the end of the flow → Messages', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    Route<void> page(RouteSettings s) =>
        MaterialPageRoute(settings: s, builder: (_) => Text(s.name ?? ''));
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        initialRoute: AppRoutes.home,
        onGenerateRoute: page,
      ),
    );
    // Home → Ask for a ride → Families near you
    navigator.currentState!
      ..pushNamed(AppRoutes.askRide)
      ..pushNamed(AppRoutes.familiesNearYou);
    await tester.pumpAndSettle();

    openChatOverMessages(navigator.currentState!, AppRoutes.groupChat);
    await tester.pumpAndSettle();
    expect(find.text(AppRoutes.groupChat), findsOneWidget);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text(AppRoutes.messages), findsOneWidget);
    expect(navigator.currentState!.canPop(), isFalse);
  });
}
