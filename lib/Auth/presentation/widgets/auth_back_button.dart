import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/auth_assets.dart';

/// Figma "Icon Button" — 56px surface circle with Icon/arrow-left.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, this.onPressed});

  /// Defaults to popping the current route.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed ?? () => Navigator.of(context).maybePop(),
          child: const SizedBox.square(
            dimension: 56,
            child: Center(child: AppIcon(AuthAssets.iconArrowLeft)),
          ),
        ),
      ),
    );
  }
}
