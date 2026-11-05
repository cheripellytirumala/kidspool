import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../providers/kids_provider.dart';
import '../widgets/kids_places_board.dart';
import '../widgets/kids_scaffold.dart';
import '../widgets/place_assignment_sheet.dart';
import '../widgets/place_search_sheet.dart';

/// Where do your kids go? — one page for the whole step:
/// - F08 (Figma 849:13732): kid tabs, "Add Facility", tip; Continue disabled.
/// - "Add Facility" opens the F09 search sheet (849:13899 / 852:14790);
///   picking a result replaces it with the F10 "Who goes here?" sheet
///   (849:14061).
/// - After Save the page shows F11 (849:13790): the kid's places, "Also:"
///   pills, trash buttons and Save → All set.
class WhereKidsGoScreen extends StatelessWidget {
  const WhereKidsGoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kids = sl<KidsProvider>();
    // No-op once loaded; covers opening this screen directly.
    Future.microtask(kids.load);
    return ChangeNotifierProvider<KidsProvider>.value(
      value: kids,
      child: const _WhereKidsGoView(),
    );
  }
}

class _WhereKidsGoView extends StatelessWidget {
  const _WhereKidsGoView();

  Future<void> _addFacility(BuildContext context) async {
    final place = await showPlaceSearchSheet(context);
    if (place == null || !context.mounted) return;
    await showPlaceAssignmentSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final kids = context.watch<KidsProvider>();
    final hasPlaces = kids.anyPlaces;

    return AppLoadingOverlay(
      isLoading: kids.isLoading,
      child: KidsScaffold(
        title: 'Where do your kids go?',
        subtitle: 'Pick a child, then add their school and activities.',
        titleGap: 4,
        bottom: AppButton(
          label: hasPlaces ? 'Save' : 'Continue',
          onPressed: hasPlaces
              ? () => Navigator.of(context).pushNamed(AppRoutes.allSet)
              : null,
        ),
        children: [
          KidsPlacesBoard(
            kids: kids,
            showDone: true,
            onAddFacility: () => _addFacility(context),
          ),
        ],
      ),
    );
  }
}
