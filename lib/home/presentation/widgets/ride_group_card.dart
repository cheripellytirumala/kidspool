import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/home_assets.dart';
import '../../core/constants/home_text_styles.dart';

/// H3 "Group · Home → Lincoln" row: the parents sharing the booked ride's
/// route, or the user's ride group. Inert while [onTap] is null.
class RideGroupCard extends StatelessWidget {
  const RideGroupCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  /// "Home → Lincoln parents"
  final String title;

  /// "6 members"
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimens.radiusRow);
    return Semantics(
      button: onTap != null,
      child: Material(
        color: AppColors.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                  child: const AppIcon(HomeAssets.rideGroup),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: HomeTextStyles.groupTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: HomeTextStyles.bodyM,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const AppIcon(HomeAssets.chevronRight, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
