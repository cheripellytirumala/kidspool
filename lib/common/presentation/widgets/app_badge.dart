import 'package:flutter/material.dart';

import '../theme/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import 'app_icon.dart';

/// Figma "Badge" — status pill with a dot: Verified, On the way, Checked in, SOS.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.background = AppColors.lime,
    this.foreground = AppColors.textOnLime,
    this.showDot = true,
  });

  final String label;
  final Color background;
  final Color foreground;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            AppIcon(AppAssets.badgeDot, size: 7, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(label, style: AppTextStyles.caption.copyWith(color: foreground)),
        ],
      ),
    );
  }
}
