import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import 'app_loader.dart';

/// Figma "Button": Lime = primary (one per screen), Dark = strong secondary,
/// Light = tertiary, Outline = low emphasis.
enum AppButtonVariant { lime, dark, light, outline }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.lime,
    this.leading,
    this.isLoading = false,
    this.height = AppDimens.buttonHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? leading;
  final bool isLoading;
  final double height;

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, border) = switch (variant) {
      AppButtonVariant.lime => (AppColors.lime, AppColors.textOnLime, null),
      AppButtonVariant.dark => (AppColors.ink, AppColors.textOnDark, null),
      AppButtonVariant.light => (
        AppColors.surface,
        AppColors.textPrimary,
        null,
      ),
      AppButtonVariant.outline => (
        Colors.transparent,
        AppColors.textPrimary,
        Border.all(color: AppColors.ink, width: 2),
      ),
    };

    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _enabled || isLoading ? 1 : 0.35,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            border: border,
            boxShadow: variant == AppButtonVariant.lime && _enabled
                ? AppDimens.buttonGlow
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: _enabled ? onPressed : null,
              customBorder: const StadiumBorder(),
              child: SizedBox(
                height: height,
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Center(
                    child: isLoading
                        ? AppLoader.glyph(size: 28, color: foreground)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (leading != null) ...[
                                leading!,
                                const SizedBox(width: 10),
                              ],
                              Flexible(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.title.copyWith(
                                    color: foreground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
