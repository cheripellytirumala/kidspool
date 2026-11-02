import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Figma "Toggle" 56×34. On = ink track + lime knob; off = gray track + white knob.
class AppToggle extends StatelessWidget {
  const AppToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 56,
          height: 34,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? AppColors.ink : AppColors.surfaceStrong,
            borderRadius: BorderRadius.circular(17),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: value ? AppColors.lime : AppColors.screen,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
