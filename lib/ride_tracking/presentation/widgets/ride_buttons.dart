import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/ride_tracking_assets.dart';
import 'ride_styles.dart';

/// Figma "Icon Button": a circle with one icon.
class RideIconButton extends StatelessWidget {
  const RideIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 44,
    this.background = AppColors.surface,
    this.iconColor,
    this.shadow,
  });

  /// White 56px back button that floats over the map.
  const RideIconButton.back({
    super.key,
    required this.onPressed,
    this.semanticLabel = 'Back',
  }) : icon = RideTrackingAssets.arrowLeft,
       size = 56,
       background = AppColors.screen,
       iconColor = null,
       shadow = RideShadows.float;

  final String icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final double size;
  final Color background;
  final Color? iconColor;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          boxShadow: shadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Center(child: AppIcon(icon, color: iconColor)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Red 56px "SOS" circle.
class RideSosButton extends StatelessWidget {
  const RideSosButton({super.key, required this.onPressed, this.busy = false});

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'SOS, emergency',
      excludeSemantics: true,
      child: Material(
        color: RideColors.sos,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: busy ? null : onPressed,
          child: SizedBox.square(
            dimension: 56,
            child: Center(
              child: Text(
                'SOS',
                style: RideTextStyles.labelM.copyWith(
                  color: AppColors.textOnDark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
