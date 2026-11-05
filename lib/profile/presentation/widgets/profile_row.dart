import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/profile_assets.dart';
import '../../core/constants/profile_styles.dart';

/// Figma "Row · …" (S18 · Profile1): 48px icon tile, title, optional
/// subtitle and a trailing chevron / badge on a 22px-radius surface.
class ProfileRow extends StatelessWidget {
  const ProfileRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.showChevron = true,
    this.background = AppColors.surface,
    this.iconBackground = AppColors.screen,
    this.titleColor,
  });

  /// Widget shown inside the 48px tile (usually a 22px [AppIcon]).
  final Widget icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Replaces the chevron (e.g. a "Verified" pill).
  final Widget? trailing;
  final bool showChevron;
  final Color background;
  final Color iconBackground;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimens.radiusRow);
    final trailingWidget =
        trailing ??
        (showChevron && onTap != null
            ? const AppIcon(ProfileAssets.chevronRight, size: 20)
            : null);
    return Semantics(
      button: onTap != null,
      child: Material(
        color: background,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: icon,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: titleColor == null
                            ? ProfileStyles.rowTitle
                            : ProfileStyles.rowTitle.copyWith(
                                color: titleColor,
                              ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: ProfileStyles.rowSubtitle),
                      ],
                    ],
                  ),
                ),
                if (trailingWidget != null) ...[
                  const SizedBox(width: 12),
                  trailingWidget,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small status pill at the end of a row ("Verified", "Default").
class ProfilePill extends StatelessWidget {
  const ProfilePill({
    super.key,
    required this.label,
    this.background = AppColors.lime,
  });

  final String label;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.only(left: 10, right: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      alignment: Alignment.center,
      child: Text(label, style: ProfileStyles.pill),
    );
  }
}
