import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../core/constants/auth_assets.dart';
import '../../core/constants/auth_styles.dart';

/// 48px pill chip on dark screens (V1 "Front" / "Back").
/// Selected = lime, otherwise charcoal.
class DarkChoiceChip extends StatelessWidget {
  const DarkChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.lime : AuthColors.charcoal,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AuthTextStyles.labelM.copyWith(
                color: selected ? AppColors.textPrimary : AppColors.textOnDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small raised pill with a capture tip ("Good light").
class CameraHintPill extends StatelessWidget {
  const CameraHintPill(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AuthColors.inverseRaised,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Text(
        label,
        style: AuthTextStyles.captionS.copyWith(color: AppColors.textOnDark),
      ),
    );
  }
}

/// 84px shutter: white ring with a lime core.
class ShutterButton extends StatelessWidget {
  const ShutterButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Take photo',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 84,
          height: 84,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.screen, width: 4),
          ),
          child: Material(
            color: AppColors.lime,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: const SizedBox.square(dimension: 66),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Gallery button" — thumbnail of the latest photo (a license) that opens
/// the photo library.
class GalleryThumbnailButton extends StatelessWidget {
  const GalleryThumbnailButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Upload from photos',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: SizedBox(
          width: 72,
          child: Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AuthColors.thumbBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.screen, width: 2),
              ),
              // Clip inside the white border, like Figma's overflow clip.
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: const Stack(
                  children: [
                    Positioned(
                      left: -4,
                      top: 7,
                      width: 60,
                      height: 38,
                      child: _LicenseThumb(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LicenseThumb extends StatelessWidget {
  const _LicenseThumb();

  static Widget _line(double top, double width) => Positioned(
    left: 21.8,
    top: top,
    width: width,
    height: 2.28,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AuthColors.thumbCardLine,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AuthColors.thumbCardStart, AuthColors.thumbCardEnd],
        ),
        border: Border.all(color: AuthColors.thumbCardBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: -1,
            top: -1,
            width: 60,
            height: 6.84,
            child: ColoredBox(color: AuthColors.thumbCardBand),
          ),
          Positioned(
            left: 2.6,
            top: 9.64,
            width: 15.6,
            height: 19,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                AuthAssets.idPortrait,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          _line(11.16, 27),
          _line(16.48, 21),
          _line(21.8, 21),
          _line(27.12, 21),
        ],
      ),
    );
  }
}
