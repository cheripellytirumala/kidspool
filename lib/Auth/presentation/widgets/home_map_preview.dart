import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../core/constants/auth_assets.dart';

/// "Map · Home preview" on S04: dark map tile, lime radius around home, the
/// home pin and an address label.
class HomeMapPreview extends StatelessWidget {
  const HomeMapPreview({super.key, required this.label, this.onTap});

  /// Address shown in the white pill; hidden when empty.
  final String label;

  /// Tapping the map (same action as "Use my current location").
  final VoidCallback? onTap;

  static const double _height = 128;

  @override
  Widget build(BuildContext context) {
    final map = ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusMap),
      child: SizedBox(
        height: _height,
        child: ColoredBox(
          color: AppColors.inverse,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // In Figma (350px wide) the pin sits 4px right of the center.
              final pinX = constraints.maxWidth / 2 + 4;
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: pinX - 409,
                    top: -380,
                    width: 800,
                    height: 900,
                    child: SvgPicture.asset(
                      AppAssets.mapDark,
                      fit: BoxFit.fill,
                    ),
                  ),
                  Positioned(
                    left: pinX - 80,
                    top: -16,
                    width: 160,
                    height: 160,
                    child: Image.asset(AppAssets.radiusAroundHome),
                  ),
                  Positioned(left: pinX - 20, top: 44, child: const _HomePin()),
                  if (label.isNotEmpty)
                    Positioned(
                      left: 12,
                      top: 12,
                      right: 12,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                          decoration: BoxDecoration(
                            color: AppColors.screen,
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusPill,
                            ),
                          ),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
    if (onTap == null) return map;
    return Semantics(
      button: true,
      label: 'Use my current location',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: map,
      ),
    );
  }
}

class _HomePin extends StatelessWidget {
  const _HomePin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.lime,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.inverse, width: 3),
        boxShadow: AppDimens.buttonGlow,
      ),
      // Icon/home at 18px: the glyph fills 79% × 76% of the icon box.
      child: SvgPicture.asset(
        AuthAssets.iconHomeGlyph,
        width: 14.25,
        height: 13.65,
      ),
    );
  }
}
