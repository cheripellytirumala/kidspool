import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/view_state.dart';
import '../providers/app_version_provider.dart';

/// Minimal launch screen that drives [AppVersionProvider].
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppVersionProvider>();

    return Scaffold(
      body: Center(
        child: switch (provider.status) {
          ViewStatus.initial ||
          ViewStatus.loading => const CircularProgressIndicator(),
          ViewStatus.failure => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(provider.errorMessage ?? ''),
              TextButton(
                onPressed: provider.fetchAppVersion,
                child: const Text('Retry'),
              ),
            ],
          ),
          ViewStatus.success => Text(
            'Latest version: ${provider.appVersion?.latestVersion}',
          ),
        },
      ),
    );
  }
}
