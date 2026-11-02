import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/home_assets.dart';
import '../../core/constants/home_text_styles.dart';

/// Lime "Action · Ask" card on the Home dashboard.
class AskRideActionCard extends StatelessWidget {
  const AskRideActionCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimens.radiusMap);
    return Semantics(
      button: true,
      child: Material(
        color: AppColors.lime,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ask for a ride', style: HomeTextStyles.headingH2),
                      const SizedBox(height: 2),
                      Text(
                        'Any child, any of their places',
                        style: HomeTextStyles.bodyM.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                  ),
                  child: const AppIcon(HomeAssets.iconCarOutline, size: 26),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
