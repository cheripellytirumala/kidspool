import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_icon.dart';

/// Figma "Icon Button": circular surface button with a centered icon
/// (56px back button, 36px sheet close, 34px trash).
class KidsIconButton extends StatelessWidget {
  const KidsIconButton({
    super.key,
    required this.asset,
    required this.onPressed,
    this.size = 56,
    this.iconSize = 24,
    this.color = AppColors.surface,
    this.tooltip,
  });

  final String asset;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: size,
          child: Center(child: AppIcon(asset, size: iconSize)),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: tooltip,
      child: tooltip == null
          ? button
          : Tooltip(message: tooltip, child: button),
    );
  }
}
