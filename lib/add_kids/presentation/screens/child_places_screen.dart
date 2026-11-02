import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../providers/kids_provider.dart';
import '../widgets/kids_places_board.dart';
import '../widgets/kids_scaffold.dart';

/// F11 · Emma’s places (Figma 1018:8535): each kid's places, shared places
/// show "Also: Noah"; the trash button removes a place from the kid.
class ChildPlacesScreen extends StatelessWidget {
  const ChildPlacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kids = sl<KidsProvider>();
    // No-op once loaded; covers opening this screen directly.
    Future.microtask(kids.load);
    return ChangeNotifierProvider<KidsProvider>.value(
      value: kids,
      child: const _ChildPlacesView(),
    );
  }
}

class _ChildPlacesView extends StatelessWidget {
  const _ChildPlacesView();

  @override
  Widget build(BuildContext context) {
    final kids = context.watch<KidsProvider>();

    return AppLoadingOverlay(
      isLoading: kids.isLoading,
      child: KidsScaffold(
        title: 'Where do your kids go?',
        subtitle: 'Pick a child, then add their school and activities.',
        titleGap: 4,
        bottom: AppButton(
          label: 'Save',
          onPressed: kids.anyPlaces
              ? () => Navigator.of(context).pushNamed(AppRoutes.allSet)
              : null,
        ),
        children: [
          KidsPlacesBoard(
            kids: kids,
            showDone: true,
            onAddFacility: () =>
                Navigator.of(context).pushNamed(AppRoutes.findSchool),
          ),
        ],
      ),
    );
  }
}
