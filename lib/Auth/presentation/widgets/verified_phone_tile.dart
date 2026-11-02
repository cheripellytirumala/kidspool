import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_badge.dart';
import '../../../common/presentation/widgets/app_icon.dart';

/// "Field · Mobile" on S04: the number verified on S03a with a Verified badge.
class VerifiedPhoneTile extends StatelessWidget {
  const VerifiedPhoneTile({super.key, required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.screen,
              shape: BoxShape.circle,
            ),
            child: const AppIcon(AppAssets.iconPhoneSmall, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mobile', style: AppTextStyles.caption),
                Text(
                  phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const AppBadge(label: 'Verified'),
        ],
      ),
    );
  }
}
