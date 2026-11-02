import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/common/core/config/environment.dart';
import 'package:kidspool/common/core/di/injection_container.dart';
import 'package:kidspool/common/presentation/theme/app_theme.dart';
import 'package:kidspool/common/presentation/widgets/app_loader.dart';
import 'package:kidspool/onboarding/presentation/providers/app_version_provider.dart';
import 'package:kidspool/onboarding/presentation/screens/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The splash mark must sit at the exact screen centre (matching the native
/// launch screen) whatever the safe-area insets are.
void main() {
  setUpAll(() async {
    final loader = FontLoader('HankenGrotesk');
    for (final w in [400, 500, 600, 700]) {
      final bytes = File('assets/fonts/HankenGrotesk-$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
    SharedPreferences.setMockInitialValues({});
    await initDependencies(config: EnvConfig.of(Environment.production));
  });

  const devices = {
    'iPhone 15': (Size(393, 852), EdgeInsets.only(top: 59, bottom: 34)),
    'iPhone SE': (Size(375, 667), EdgeInsets.only(top: 20)),
    'Pixel 7': (Size(412, 915), EdgeInsets.only(top: 24, bottom: 48)),
  };

  devices.forEach((name, device) {
    testWidgets('splash mark is centred on $name', (tester) async {
      final (size, padding) = device;
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1
        ..padding = FakeViewPadding(top: padding.top, bottom: padding.bottom);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => sl<AppVersionProvider>(),
          child: MaterialApp(theme: AppTheme.light, home: const SplashScreen()),
        ),
      );
      await tester.pump();

      final mark = tester.getCenter(find.byType(AppLoader));
      expect(mark.dx, moreOrLessEquals(size.width / 2, epsilon: 0.5));
      expect(mark.dy, moreOrLessEquals(size.height / 2, epsilon: 0.5));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
