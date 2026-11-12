import 'dart:async';

import 'common/presentation/state/live_refresh.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'common/core/constants/app_constants.dart';
import 'common/core/di/injection_container.dart';
import 'common/core/router/app_router.dart';
import 'common/core/router/app_routes.dart';
import 'common/presentation/theme/app_theme.dart';
import 'common/presentation/widgets/extra_top_inset.dart';
import 'notifications/core/services/ride_notifications.dart';
import 'onboarding/presentation/providers/app_version_provider.dart';
import 'ride_tracking/presentation/widgets/ride_alerts_host.dart';

/// Lets the ride alerts banner (above the Navigator) open screens.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  // S19 / S20 system notifications + push (push stays off without Firebase
  // config). Not awaited: never delays the first frame.
  unawaited(sl<RideNotifications>().init(navigatorKey: rootNavigatorKey));
  // Keeps tabs and the Messages badge current while the app is open.
  LiveRefresh.instance.start();
  runApp(const KidsPoolApp());
}

class KidsPoolApp extends StatelessWidget {
  const KidsPoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    // App-wide providers only. Feature providers are created per screen from
    // `sl` so their state is scoped to the flow that uses it.
    return ChangeNotifierProvider(
      create: (_) => sl<AppVersionProvider>(),
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        navigatorKey: rootNavigatorKey,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRouter.onGenerateRoute,
        // S19 / S20: "Ride started" / "Arrived" banners over every screen.
        // ExtraTopInset: 7px more space under the status bar on every screen.
        builder: (context, child) => ExtraTopInset(
          child: RideAlertsHost(navigatorKey: rootNavigatorKey, child: child!),
        ),
      ),
    );
  }
}
