import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/common/core/config/environment.dart';
import 'package:kidspool/common/core/di/injection_container.dart';
import 'package:kidspool/common/core/router/app_router.dart';
import 'package:kidspool/common/core/router/app_routes.dart';
import 'package:kidspool/common/presentation/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opens every screen of the easy flow and fails on any build/layout error
/// (including RenderFlex overflows) at a standard and a small phone size.
void main() {
  const routes = [
    AppRoutes.phoneNumber,
    AppRoutes.otp,
    AppRoutes.aboutYou,
    AppRoutes.scanPhotoId,
    AppRoutes.idVerified,
    AppRoutes.addChild,
    AppRoutes.yourKids,
    AppRoutes.whereKidsGo,
    AppRoutes.findSchool,
    AppRoutes.whoGoesWhen,
    AppRoutes.childPlaces,
    AppRoutes.allSet,
    AppRoutes.home,
    AppRoutes.familiesNearYou,
    AppRoutes.askRide,
    AppRoutes.messageSent,
    AppRoutes.profile,
    AppRoutes.liveTracking,
    AppRoutes.rideCompleted,
  ];

  setUpAll(() async {
    // Real font metrics, so overflow checks match devices (the default test
    // font renders every glyph as a 1em square).
    final loader = FontLoader('HankenGrotesk');
    for (final w in [400, 500, 600, 700]) {
      final bytes = File('assets/fonts/HankenGrotesk-$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();

    SharedPreferences.setMockInitialValues({});
    await initDependencies(config: EnvConfig.of(Environment.production));
  });

  for (final size in const [Size(390, 844), Size(320, 568)]) {
    for (final route in routes) {
      testWidgets(
        '$route renders at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              onGenerateRoute: AppRouter.onGenerateRoute,
              // Open only this route (initialRoute would also build '/' etc.).
              onGenerateInitialRoutes: (_) => [
                AppRouter.onGenerateRoute(RouteSettings(name: route))!,
              ],
            ),
          );
          await tester.pump(const Duration(seconds: 2));

          expect(tester.takeException(), isNull);
          expect(find.byType(Scaffold), findsWidgets);

          // Dispose cleanly so pending timers (e.g. OTP countdown) are cancelled.
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        },
      );
    }
  }
}
