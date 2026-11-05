import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../core/constants/kids_assets.dart';
import '../../core/constants/kids_styles.dart';
import '../providers/kids_provider.dart';
import '../providers/place_assignment_provider.dart';
import 'icon_disc.dart';
import 'kid_select_chip.dart';
import 'kids_sheet.dart';

/// Opens F10 · Who goes here? (Figma 849:14061) for
/// [KidsProvider.pendingPlace]. Completes with `true` once saved; a closed
/// sheet clears the pending place.
Future<bool> showPlaceAssignmentSheet(BuildContext context) async {
  final kids = context.read<KidsProvider>();
  final saved = await showKidsSheet<bool>(
    context,
    (_) => MultiProvider(
      providers: [
        ChangeNotifierProvider<KidsProvider>.value(value: kids),
        ChangeNotifierProvider<PlaceAssignmentProvider>(
          create: (_) => sl<PlaceAssignmentProvider>(),
        ),
      ],
      child: const PlaceAssignmentSheet(),
    ),
  );
  if (saved != true && kids.pendingPlace != null) kids.setPendingPlace(null);
  return saved == true;
}

/// Place header, "WHO GOES HERE?" kid chips and Save. Schools are saved on
/// the server (`update-kid` schoolId), activities on the device.
class PlaceAssignmentSheet extends StatelessWidget {
  const PlaceAssignmentSheet({super.key});

  Future<void> _save(
    BuildContext context,
    PlaceAssignmentProvider assignment,
  ) async {
    final error = await assignment.save();
    if (!context.mounted) return;
    if (error != null) return showAppSnack(context, error);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final kids = context.watch<KidsProvider>();
    final assignment = context.watch<PlaceAssignmentProvider>();
    final place = assignment.place;

    // isLoading covers the reload of the kids right after saving.
    return AppLoadingOverlay(
      isLoading: assignment.isSaving || kids.isLoading,
      message: 'Saving…',
      child: KidsSheet(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  spacing: 12,
                  children: [
                    if (place != null)
                      IconDisc(
                        asset: KidsAssets.placeIcon(place.category, 23),
                        size: 48,
                        iconSize: 23,
                        color: AppColors.lime,
                        iconColor: AppColors.ink,
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 1,
                        children: [
                          Text(
                            place?.name ?? 'Pick a place first',
                            style: AppTextStyles.headingH3,
                          ),
                          if (place != null && place.details.isNotEmpty)
                            Text(place.details, style: KidsTextStyles.captionM),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const KidsSheetCloseButton(),
            ],
          ),
          Text('WHO GOES HERE?', style: KidsTextStyles.captionM),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = kids.children.length == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final child in kids.children)
                    SizedBox(
                      width: width,
                      child: KidSelectChip(
                        child: child,
                        selected: assignment.isSelected(child.id),
                        onTap: () => assignment.toggle(child.id),
                      ),
                    ),
                ],
              );
            },
          ),
          AppButton(
            label: 'Save',
            isLoading: assignment.isSaving,
            onPressed: assignment.canSave
                ? () => _save(context, assignment)
                : null,
          ),
        ],
      ),
    );
  }
}
