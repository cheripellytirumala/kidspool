import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../providers/kids_provider.dart';
import '../widgets/kids_places_board.dart';
import '../widgets/kids_scaffold.dart';

/// F08 · Where do your kids go? (Figma 1018:8482): pick a kid, then add
/// their school and activities.
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

  @override
  Widget build(BuildContext context) {
    final kids = context.watch<KidsProvider>();
    void findSchool() => Navigator.of(context).pushNamed(AppRoutes.findSchool);

    return AppLoadingOverlay(
      isLoading: kids.isLoading,
      child: KidsScaffold(
        title: 'Where do your kids go?',
        subtitle: 'Pick a child, then add their school and activities.',
        titleGap: 4,
        bottom: AppButton(
          label: 'Continue',
          onPressed: kids.anyPlaces ? findSchool : null,
        ),
        children: [KidsPlacesBoard(kids: kids, onAddFacility: findSchool)],
      ),
    );
  }
}
