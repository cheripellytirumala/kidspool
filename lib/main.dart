import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'common/core/constants/app_constants.dart';
import 'common/core/di/injection_container.dart';
import 'common/core/router/app_router.dart';
import 'common/core/router/app_routes.dart';
import 'common/presentation/theme/app_theme.dart';
import 'onboarding/presentation/providers/app_version_provider.dart';
import 'ride_tracking/presentation/widgets/ride_alerts_host.dart';

/// Lets the ride alerts banner (above the Navigator) open screens.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
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
        builder: (context, child) =>
            RideAlertsHost(navigatorKey: rootNavigatorKey, child: child!),
      ),
    );
  }
}
