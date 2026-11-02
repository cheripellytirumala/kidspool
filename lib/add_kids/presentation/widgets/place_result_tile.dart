import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../core/constants/kids_assets.dart';
import '../../core/constants/kids_styles.dart';
import '../../domain/entities/place.dart';
import 'icon_disc.dart';

/// Search result in the F09 sheet. Unselected: "Result · Lincoln
/// Elementary"; selected: "Club · Westside" (lime-soft, 2.5px ink border,
/// lime disc and check).
class PlaceResultTile extends StatelessWidget {
  const PlaceResultTile({
    super.key,
    required this.place,
    required this.selected,
    required this.onTap,
  });

  final Place place;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: selected
          ? const BorderSide(color: AppColors.ink, width: 2.5)
          : BorderSide.none,
    );
    final iconSize = selected ? 24.0 : 21.0;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.limeTint : AppColors.surface,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Padding(
            padding: EdgeInsets.all(selected ? 14 : 12),
            child: Row(
              spacing: selected ? 14 : 12,
              children: [
                IconDisc(
                  asset: KidsAssets.placeIcon(place.category, iconSize),
                  size: selected ? 48 : 44,
                  iconSize: iconSize,
                  color: selected ? AppColors.lime : AppColors.screen,
                  iconColor: AppColors.ink,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        place.name,
                        style: selected
                            ? KidsTextStyles.titleL
                            : KidsTextStyles.labelL,
                      ),
                      if (place.details.isNotEmpty)
                        Text(
                          place.details,
                          style: selected
                              ? KidsTextStyles.bodyM
                              : KidsTextStyles.captionM,
                        ),
                    ],
                  ),
                ),
                if (selected)
                  const IconDisc(
                    asset: KidsAssets.check18,
                    size: 30,
                    iconSize: 18,
                    color: AppColors.ink,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
