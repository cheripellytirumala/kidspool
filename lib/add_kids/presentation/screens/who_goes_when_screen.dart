import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../core/constants/kids_assets.dart';
import '../../core/constants/kids_styles.dart';
import '../providers/kids_provider.dart';
import '../providers/place_assignment_provider.dart';
import '../widgets/icon_disc.dart';
import '../widgets/kid_select_chip.dart';
import '../widgets/kids_places_board.dart';
import '../widgets/kids_scaffold.dart';
import '../widgets/kids_sheet.dart';

/// F10 · Who goes & when (Figma 1018:8974): sheet over the places board
/// asking which kids go to the place picked on F09.
class WhoGoesWhenScreen extends StatelessWidget {
  const WhoGoesWhenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<KidsProvider>.value(value: sl<KidsProvider>()),
        ChangeNotifierProvider<PlaceAssignmentProvider>(
          create: (_) => sl<PlaceAssignmentProvider>(),
        ),
      ],
      child: const _WhoGoesWhenView(),
    );
  }
}

class _WhoGoesWhenView extends StatelessWidget {
  const _WhoGoesWhenView();

  Future<void> _save(
    BuildContext context,
    PlaceAssignmentProvider assignment,
  ) async {
    final error = await assignment.save();
    if (!context.mounted) return;
    if (error != null) return showAppSnack(context, error);
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.childPlaces,
      (route) => route.settings.name == AppRoutes.whereKidsGo || route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final kids = context.watch<KidsProvider>();
    final assignment = context.watch<PlaceAssignmentProvider>();
    final place = assignment.place;

    return Scaffold(
      backgroundColor: AppColors.screen,
      resizeToAvoidBottomInset: false,
      // isLoading covers the reload of the kids right after saving.
      body: AppLoadingOverlay(
        isLoading: assignment.isSaving || kids.isLoading,
        message: 'Saving…',
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The places board stays visible (but inert) behind the scrim.
            IgnorePointer(
              child: ExcludeSemantics(
                child: KidsScaffold(
                  showBack: false,
                  title: 'Where do your kids go?',
                  subtitle:
                      'Pick a child, then add their school and activities.',
                  titleGap: 4,
                  bottom: const AppButton(label: 'Continue', onPressed: null),
                  children: [KidsPlacesBoard(kids: kids, onAddFacility: null)],
                ),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: const ColoredBox(color: KidsColors.scrim),
            ),
            Align(
              alignment: Alignment.bottomCenter,
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
                                    Text(
                                      place.details,
                                      style: KidsTextStyles.captionM,
                                    ),
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
            ),
          ],
        ),
      ),
    );
  }
}
