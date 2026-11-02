import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'AskRide/presentation/providers/ask_ride_provider.dart';
import 'Auth/presentation/providers/auth_provider.dart';
import 'core/constants/app_constants.dart';
import 'core/di/injection_container.dart';
import 'presentation/providers/app_version_provider.dart';
import 'presentation/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  runApp(const KidsPoolApp());
}

class KidsPoolApp extends StatelessWidget {
  const KidsPoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => sl<AppVersionProvider>()..fetchAppVersion(),
        ),
        ChangeNotifierProvider(create: (_) => sl<AuthProvider>()),
        ChangeNotifierProvider(create: (_) => sl<AskRideProvider>()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.deepPurple),
        home: const SplashScreen(),
      ),
    );
  }
}
