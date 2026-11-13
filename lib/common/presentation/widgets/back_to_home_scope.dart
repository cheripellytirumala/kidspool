import 'package:flutter/material.dart';

import '../../core/router/app_routes.dart';

/// In-app screens: when the screen is the only one on the stack (a tab
/// other than Home, or a page opened from a notification), Back — the
/// system back gesture or a back button using `maybePop` — goes to Home
/// instead of closing the app or doing nothing. With pages below, Back
/// pops as usual.
///
/// With [popToRoot] (ride request, live ride, ride summary), Back skips
/// every page in between and lands on the tab underneath (the dashboard),
/// however many ride pages were opened on top of each other.
class BackToHomeScope extends StatelessWidget {
  const BackToHomeScope({
    super.key,
    required this.child,
    this.popToRoot = false,
  });

  final Widget child;
  final bool popToRoot;

  @override
  Widget build(BuildContext context) {
    final isRoot = ModalRoute.of(context)?.isFirst ?? false;
    return PopScope(
      canPop: !isRoot && !popToRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (ModalRoute.of(context)?.isFirst ?? true) {
          navigator.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
        } else {
          navigator.popUntil((r) => r.isFirst);
        }
      },
      child: child,
    );
  }
}
