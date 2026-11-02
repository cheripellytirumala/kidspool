import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_select_card.dart';
import '../../core/constants/ask_ride_assets.dart';
import '../../domain/entities/saved_place.dart';
import 'ask_ride_sheet.dart';

/// What the user did in [PlacePickerSheet].
sealed class PlacePickerResult {
  const PlacePickerResult();
}

/// Picked one of the saved places.
final class PlacePicked extends PlacePickerResult {
  const PlacePicked(this.place);

  final SavedPlace place;
}

/// Wants to search a new address on the map.
final class AddNewPlace extends PlacePickerResult {
  const AddNewPlace();
}

/// Lists the family's saved places, plus "Add a new address" (Google map
/// search). Pops with a [PlacePickerResult].
class PlacePickerSheet extends StatelessWidget {
  const PlacePickerSheet({
    super.key,
    required this.title,
    required this.places,
    required this.selected,
  });

  final String title;
  final List<SavedPlace> places;
  final SavedPlace? selected;

  @override
  Widget build(BuildContext context) {
    return AskRideSheet(
      title: title,
      children: [
        for (final place in places)
          AppSelectCard(
            title: place.name,
            subtitle: [place.address, ?place.detail].join(' · '),
            icon: place.kind == PlaceKind.home
                ? SvgPicture.asset(AppAssets.iconHome, width: 19, height: 18.2)
                : SvgPicture.asset(AskRideAssets.school, width: 25, height: 25),
            selected: place == selected,
            onTap: () => Navigator.of(context).pop(PlacePicked(place)),
          ),
        _AddNewAddressTile(
          onTap: () => Navigator.of(context).pop(const AddNewPlace()),
        ),
      ],
    );
  }
}

class _AddNewAddressTile extends StatelessWidget {
  const _AddNewAddressTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add a new address. Search on Google Maps',
      excludeSemantics: true,
      child: Material(
        color: AppColors.screen,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          side: const BorderSide(color: AppColors.ink, width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                  child: const AppIcon(AppAssets.iconPlus, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add a new address', style: AppTextStyles.title),
                      const SizedBox(height: 2),
                      Text(
                        'Search on Google Maps',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const AppIcon(AppAssets.iconSearch, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
