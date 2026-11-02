import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../core/constants/ask_ride_assets.dart';
import '../../domain/entities/saved_place.dart';
import 'ask_ride_text_styles.dart';

/// Circle holding a centred icon (white 36px discs, 40px place discs…).
class IconDisc extends StatelessWidget {
  const IconDisc({
    super.key,
    required this.child,
    this.size = 36,
    this.color = AppColors.screen,
  });

  final Widget child;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: child,
    );
  }
}

/// Figma "Icon Button" (56px surface circle) used as the back button.
class AskRideBackButton extends StatelessWidget {
  const AskRideBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).maybePop(),
          child: SizedBox.square(
            dimension: 56,
            child: Center(
              child: SvgPicture.asset(
                AskRideAssets.arrowLeft,
                width: 24,
                height: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Place glyph in a 40px disc: home = ink + lime house, school = lime tint
/// + graduation cap.
class PlaceIcon extends StatelessWidget {
  const PlaceIcon({super.key, required this.kind});

  final PlaceKind kind;

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      PlaceKind.home => IconDisc(
        size: 40,
        color: AppColors.ink,
        child: SvgPicture.asset(
          AppAssets.iconHome,
          width: 19,
          height: 18.2,
          colorFilter: const ColorFilter.mode(AppColors.lime, BlendMode.srcIn),
        ),
      ),
      PlaceKind.school => IconDisc(
        size: 40,
        color: AppColors.limeTint,
        child: SvgPicture.asset(AskRideAssets.school, width: 25, height: 25),
      ),
    };
  }
}

/// Small 16px outline glyph for a place (return-trip summary).
class PlaceGlyph extends StatelessWidget {
  const PlaceGlyph({super.key, required this.kind});

  final PlaceKind kind;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      kind == PlaceKind.school
          ? AskRideAssets.schoolSmall
          : AskRideAssets.homeOutlineSmall,
      width: 16,
      height: 16,
    );
  }
}

/// Full-width pill with an icon and label and no glow (sheet "Done",
/// F20 actions).
class AskRideActionButton extends StatelessWidget {
  const AskRideActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.background = AppColors.lime,
    this.height = 62,
    this.gap = 10,
    this.iconSize = 22,
    this.textStyle,
  });

  final String label;
  final String icon;
  final VoidCallback? onPressed;
  final Color background;
  final double height;
  final double gap;
  final double iconSize;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: background,
          shape: const StadiumBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const StadiumBorder(),
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(icon, width: iconSize, height: iconSize),
                  SizedBox(width: gap),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle ?? AskRideTextStyles.actionButton,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Surface pill row with a label and an [AppToggle]-style trailing widget
/// ("Return trip (back home)", "One booster seat needed").
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.toggle,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Widget toggle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            child: Row(
              children: [
                Expanded(child: Text(label, style: AskRideTextStyles.labelM)),
                const SizedBox(width: 12),
                toggle,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Radius used by the frequency cards.
const double kOptionCardRadius = 24;

/// Radius of the field rows (time, note).
const double kFieldRowRadius = AppDimens.radiusRow;
