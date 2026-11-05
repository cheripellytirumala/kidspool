import 'package:flutter/material.dart';

import '../theme/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_icon.dart';

/// Square 22px checkbox (ink fill + lime check) with a label.
class AppCheckboxRow extends StatelessWidget {
  const AppCheckboxRow({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value ? AppColors.ink : AppColors.screen,
                  borderRadius: BorderRadius.circular(7),
                  border: value
                      ? null
                      : Border.all(color: AppColors.borderField, width: 2),
                ),
                child: value
                    ? const AppIcon(AppAssets.iconCheckBox, size: 12)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: AppTextStyles.label)),
            ],
          ),
        ),
      ),
    );
  }
}
