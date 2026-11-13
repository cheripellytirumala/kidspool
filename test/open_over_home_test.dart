import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/common/core/router/app_routes.dart';
import 'package:kidspool/common/core/router/open_chat.dart';

void main() {
  testWidgets('notification tap leaves only Home under the ride', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        initialRoute: AppRoutes.home,
        onGenerateInitialRoutes: (name) => [
          MaterialPageRoute<void>(
            settings: RouteSettings(name: name),
            builder: (_) => const Text('HOME'),
          ),
        ],
        onGenerateRoute: (s) => MaterialPageRoute<void>(
          settings: s,
          builder: (_) =>
              Text(s.name == AppRoutes.home ? 'HOME' : 'PAGE ${s.name}'),
        ),
      ),
    );
    // Ride request → live ride → summary already on the stack.
    key.currentState!
      ..pushNamed(AppRoutes.rideRequestDetail)
      ..pushNamed(AppRoutes.liveTracking)
      ..pushNamed(AppRoutes.rideCompleted);
    await tester.pumpAndSettle();

    openOverHome(key.currentState!, AppRoutes.liveTracking);
    await tester.pumpAndSettle();
    expect(find.text('PAGE ${AppRoutes.liveTracking}'), findsOneWidget);

    key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(key.currentState!.canPop(), isFalse);
  });
}
