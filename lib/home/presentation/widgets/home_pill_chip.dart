import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/home_text_styles.dart';

/// Pill chip used for the F14 place switch (selected = ink) and the filter
/// row (selected = lime).
class HomePillChip extends StatelessWidget {
  const HomePillChip.place({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  }) : _selectedColor = AppColors.ink,
       _padding = const EdgeInsets.fromLTRB(10, 8, 12, 8),
       _filter = false;

  const HomePillChip.filter({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  }) : icon = null,
       _selectedColor = AppColors.lime,
       _padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
       _filter = true;

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Optional 16px icon asset (place chips).
  final String? icon;
  final Color _selectedColor;
  final EdgeInsets _padding;
  final bool _filter;

  @override
  Widget build(BuildContext context) {
    final onInk = selected && _selectedColor == AppColors.ink;
    final textColor = onInk ? AppColors.textOnDark : AppColors.textPrimary;
    final baseStyle = _filter ? HomeTextStyles.captionM : HomeTextStyles.labelM;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? _selectedColor : AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: _padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  AppIcon(
                    icon!,
                    size: 16,
                    color: onInk ? AppColors.lime : AppColors.ink,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(label, style: baseStyle.copyWith(color: textColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
