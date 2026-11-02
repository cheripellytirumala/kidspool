import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/home_assets.dart';

/// 32px rounded checkbox from F14: ink fill + lime check when checked.
class SelectBox extends StatelessWidget {
  const SelectBox({super.key, required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: checked ? AppColors.ink : AppColors.screen,
        borderRadius: BorderRadius.circular(10),
        border: checked
            ? null
            : Border.all(color: AppColors.borderField, width: 2),
      ),
      child: checked ? const AppIcon(HomeAssets.iconCheckLime, size: 18) : null,
    );
  }
}
