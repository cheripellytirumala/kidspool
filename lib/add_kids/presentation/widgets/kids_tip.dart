import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/kids_assets.dart';
import '../../core/constants/kids_styles.dart';

/// Lime-soft "Tip" banner with the people icon.
class KidsTip extends StatelessWidget {
  const KidsTip({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.limeTint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        spacing: 10,
        children: [
          const AppIcon(KidsAssets.people18, size: 18),
          Expanded(
            child: Text(
              text,
              style: KidsTextStyles.captionM.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
