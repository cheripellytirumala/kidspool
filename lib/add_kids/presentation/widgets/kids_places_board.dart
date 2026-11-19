import 'package:flutter/material.dart';

import '../../../common/presentation/widgets/app_snack.dart';

import '../providers/kids_provider.dart';
import 'kid_tab.dart';
import 'kids_tip.dart';
import 'places_group_card.dart';
import '../../../common/presentation/theme/app_colors.dart';

/// Kid tabs + the selected kid's places + tip on WhereKidsGoScreen: F08
/// (empty, also behind the F09/F10 sheets) and F11 (filled).
class KidsPlacesBoard extends StatelessWidget {
  const KidsPlacesBoard({
    super.key,
    required this.kids,
    required this.onAddFacility,
    this.showDone = false,
  });

  final KidsProvider kids;
  final VoidCallback? onAddFacility;

  /// Shows the check on kids that already have places (F11).
  final bool showDone;

  @override
  Widget build(BuildContext context) {
    final active = kids.activeChild;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        _KidTabs(kids: kids, showDone: showDone),
        PlacesGroupCard(
          onAdd: onAddFacility,
          entries: active == null
              ? const []
              : [
                  for (final place in kids.placesFor(active.id))
                    PlaceEntry(
                      place: place,
                      alsoGoing: kids.alsoGoing(place.id, active.id),
                    ),
                ],
          onRemove: (place) async {
            if (active == null) return;
            // Ask first: removing can't be undone.
            final ok = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: AppColors.screen,
                title: Text('Remove ${place.name}?'),
                content: Text(
                  '${active.firstName} will no longer be linked to '
                  '${place.name}.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            );
            if (ok != true || !context.mounted) return;
            final error = kids.removePlaceFor(place.id, active.id);
            if (error != null) showAppSnack(context, error);
          },
        ),
        // Only useful with two or more kids.
        if (kids.children.length > 1)
          const KidsTip(
            text:
                'Another kid goes to the same place? Select them too—no need '
                'to add it twice.',
          ),
      ],
    );
  }
}

class _KidTabs extends StatelessWidget {
  const _KidTabs({required this.kids, required this.showDone});

  final KidsProvider kids;
  final bool showDone;

  @override
  Widget build(BuildContext context) {
    final active = kids.activeChild;
    final tabs = [
      for (final child in kids.children)
        KidTab(
          child: child,
          subtitle: kids.placesLabel(child.id),
          selected: child.id == active?.id,
          done: showDone && kids.placeCount(child.id) > 0,
          onTap: () => kids.selectChild(child.id),
        ),
    ];

    if (tabs.length <= 2) {
      return Row(
        spacing: 8,
        children: [for (final tab in tabs) Expanded(child: tab)],
      );
    }
    // 3+ kids: two per row, so every child is in view (a sideways scroll
    // hid the third and fourth).
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tab in tabs) SizedBox(width: width, child: tab),
          ],
        );
      },
    );
  }
}
