import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_icon.dart';

/// Circular surface button with a centered icon (Figma "Icon Button",
/// bell, sheet close).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.asset,
    required this.onPressed,
    required this.tooltip,
    this.size = 56,
    this.iconSize = 24,
    this.background = AppColors.surface,
  });

  final String asset;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;
  final double iconSize;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: size,
            child: Center(child: AppIcon(asset, size: iconSize)),
          ),
        ),
      ),
    );
  }
}
