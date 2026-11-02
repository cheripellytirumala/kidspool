import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../providers/kids_provider.dart';
import '../widgets/dashed_add_button.dart';
import '../widgets/kid_summary_card.dart';
import '../widgets/kids_scaffold.dart';
import 'add_child_screen.dart';

/// F07 · Your kids (Figma 1018:9179): the kids added so far.
class YourKidsScreen extends StatelessWidget {
  const YourKidsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kids = sl<KidsProvider>();
    // No-op once loaded; covers opening this screen directly.
    Future.microtask(kids.load);
    return ChangeNotifierProvider<KidsProvider>.value(
      value: kids,
      child: const _YourKidsView(),
    );
  }
}

class _YourKidsView extends StatelessWidget {
  const _YourKidsView();

  void _openEditor(BuildContext context, {String? childId}) {
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.addChild, arguments: AddChildArgs(childId: childId));
  }

  @override
  Widget build(BuildContext context) {
    final kids = context.watch<KidsProvider>();

    return AppLoadingOverlay(
      isLoading: kids.isLoading,
      child: KidsScaffold(
        title: 'Add a child',
        subtitle: 'Add each child who needs rides.',
        topPadding: 4,
        bottom: AppButton(
          label: 'Continue',
          onPressed: kids.hasChildren
              ? () => Navigator.of(context).pushNamed(AppRoutes.whereKidsGo)
              : null,
        ),
        children: [
          for (final child in kids.children)
            KidSummaryCard(
              child: child,
              onEdit: () => _openEditor(context, childId: child.id),
            ),
          DashedAddButton(
            label: 'Add another child',
            onTap: () => _openEditor(context),
          ),
        ],
      ),
    );
  }
}
