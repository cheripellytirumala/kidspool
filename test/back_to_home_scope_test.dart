import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/common/core/router/app_routes.dart';
import 'package:kidspool/common/presentation/widgets/back_to_home_scope.dart';

Widget _app(String initial) => MaterialApp(
  initialRoute: initial,
  // Only the tab itself on the stack, as after a tab switch.
  onGenerateInitialRoutes: (name) => [_route(RouteSettings(name: name))],
  onGenerateRoute: _route,
);

Route<void> _route(RouteSettings s) => MaterialPageRoute<void>(
  settings: s,
  builder: (context) => s.name == AppRoutes.home
      ? const Text('HOME')
      : BackToHomeScope(
          child: Column(
            children: [
              Text('PAGE ${s.name}'),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('back'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/detail'),
                child: const Text('open'),
              ),
            ],
          ),
        ),
);

void main() {
  testWidgets('Back on a root tab goes Home', (tester) async {
    await tester.pumpWidget(_app(AppRoutes.messages));
    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('Back with a page below pops normally', (tester) async {
    await tester.pumpWidget(_app(AppRoutes.messages));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE /detail'), findsOneWidget);
    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE ${AppRoutes.messages}'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('Back on a stacked ride page lands on the dashboard', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    Route<void> ride(RouteSettings s) => MaterialPageRoute<void>(
      settings: s,
      builder: (context) => s.name == AppRoutes.home
          ? const Text('HOME')
          : BackToHomeScope(
              popToRoot: true,
              child: TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text('back ${s.name}'),
              ),
            ),
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        initialRoute: AppRoutes.home,
        onGenerateInitialRoutes: (n) => [ride(RouteSettings(name: n))],
        onGenerateRoute: ride,
      ),
    );
    key.currentState!
      ..pushNamed(AppRoutes.rideRequestDetail)
      ..pushNamed(AppRoutes.liveTracking)
      ..pushNamed(AppRoutes.rideCompleted);
    await tester.pumpAndSettle();
    await tester.tap(find.text('back ${AppRoutes.rideCompleted}'));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(key.currentState!.canPop(), isFalse);
  });
}
