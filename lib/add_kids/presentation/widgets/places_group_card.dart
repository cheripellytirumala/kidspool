import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../core/constants/kids_assets.dart';
import '../../core/constants/kids_styles.dart';
import '../../domain/entities/child.dart';
import '../../domain/entities/place.dart';
import 'icon_disc.dart';
import 'kid_avatar.dart';
import 'kids_icon_button.dart';

/// One row of [PlacesGroupCard]: a place plus the other kids going there.
class PlaceEntry {
  const PlaceEntry({required this.place, this.alsoGoing = const []});

  final Place place;
  final List<Child> alsoGoing;
}

/// "Group · Emma’s school": "Add Facility" header and the kid's places.
class PlacesGroupCard extends StatelessWidget {
  const PlacesGroupCard({
    super.key,
    required this.entries,
    required this.onAdd,
    required this.onRemove,
  });

  final List<PlaceEntry> entries;
  final VoidCallback? onAdd;
  final ValueChanged<Place> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Semantics(
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAdd,
              child: Row(
                spacing: 10,
                children: [
                  const IconDisc(
                    asset: KidsAssets.grad15,
                    size: 32,
                    iconSize: 15,
                    color: AppColors.ink,
                  ),
                  Expanded(
                    child: Text('Add Facility', style: AppTextStyles.headingH3),
                  ),
                  const IconDisc(
                    asset: KidsAssets.plus16,
                    size: 32,
                    iconSize: 16,
                    color: AppColors.lime,
                  ),
                ],
              ),
            ),
          ),
          for (final entry in entries)
            _PlaceRow(entry: entry, onRemove: () => onRemove(entry.place)),
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.entry, required this.onRemove});

  final PlaceEntry entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final place = entry.place;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        spacing: 12,
        children: [
          IconDisc(
            asset: KidsAssets.placeIcon(place.category, 20),
            size: 42,
            iconSize: 20,
            color: AppColors.lime,
            iconColor: AppColors.ink,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(place.name, style: KidsTextStyles.labelL),
                if (entry.alsoGoing.isNotEmpty)
                  _AlsoGoingPill(kids: entry.alsoGoing),
              ],
            ),
          ),
          KidsIconButton(
            asset: KidsAssets.trash,
            size: 34,
            iconSize: 18,
            tooltip: 'Remove ${place.name}',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _AlsoGoingPill extends StatelessWidget {
  const _AlsoGoingPill({required this.kids});

  final List<Child> kids;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(3, 2, 8, 2),
      decoration: const ShapeDecoration(
        color: AppColors.limeTint,
        shape: StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          KidAvatar(child: kids.first, size: 18),
          Flexible(
            child: Text(
              'Also: ${kids.map((k) => k.firstName).join(', ')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KidsTextStyles.captionM.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
