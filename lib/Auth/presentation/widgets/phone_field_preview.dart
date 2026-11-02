import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_icon.dart';

/// Non-editable copy of the focused "Input · Phone" field, shown behind the
/// S03a code sheet.
class PhoneFieldPreview extends StatelessWidget {
  const PhoneFieldPreview({super.key, required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusField),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Row(
        children: [
          const AppIcon(AppAssets.iconPhone, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mobile number', style: AppTextStyles.caption),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headingH3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
