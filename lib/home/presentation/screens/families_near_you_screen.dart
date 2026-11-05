import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../core/constants/home_assets.dart';
import '../../core/constants/home_text_styles.dart';
import '../../domain/entities/kid_place.dart';
import '../providers/families_near_you_provider.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/family_list_card.dart';
import '../widgets/home_pill_chip.dart';
import '../widgets/ride_summary_card.dart';
import '../widgets/select_box.dart';
import '../widgets/send_message_sheet.dart';

/// F14 · Families near you.
///
/// * Browse (Figma 1018:11305): place switch + family list. Tapping a family
///   starts selecting with that family checked.
/// * Select (1018:9238 / 1018:9436): ride summary, filters, "Select All",
///   checkable rows, Cancel / Say Hi → "Send Message" sheet → message sent.
///
/// Families come from `get_families_near_me`; the place switch has one chip
/// per school in the results. Pull to refresh.
///
/// Push with `arguments: FamiliesNearYouScreen.selectArgument` (or `true`)
/// to open straight in select mode from the ask-for-a-ride flow.
class FamiliesNearYouScreen extends StatelessWidget {
  const FamiliesNearYouScreen({super.key, this.startInSelectMode});

  /// Overrides the route argument when set.
  final bool? startInSelectMode;

  static const String selectArgument = 'select';

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.settingsOf(context)?.arguments;
    final select =
        startInSelectMode ?? (args == selectArgument || args == true);

    return ChangeNotifierProvider<FamiliesNearYouProvider>(
      create: (_) {
        final provider = sl<FamiliesNearYouProvider>();
        if (select) provider.startInSelectMode();
        Future.microtask(provider.load);
        return provider;
      },
      child: const _FamiliesView(),
    );
  }
}

class _FamiliesView extends StatelessWidget {
  const _FamiliesView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FamiliesNearYouProvider>();
    final selecting = provider.isSelecting;

    return PopScope(
      // Back while selecting (opened from Home) returns to browsing.
      canPop: !selecting || provider.startedInSelectMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) provider.cancelSelection();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: AppColors.screen,
          body: AppLoadingOverlay(
            isLoading: provider.isLoading,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: CircleIconButton(
                      asset: HomeAssets.iconArrowLeft,
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: provider.load,
                      color: AppColors.ink,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          Text(
                            'Families near you',
                            style: AppTextStyles.displayL,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Going to the same places as your kids',
                            style: HomeTextStyles.bodyM,
                          ),
                          const SizedBox(height: 12),
                          if (selecting) ...[
                            if (provider.ride case final ride?)
                              RideSummaryCard(
                                ride: ride,
                                onEdit: () => _editRide(context, provider),
                              ),
                            if (provider.families.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const _FilterRow(),
                              const SizedBox(height: 12),
                              _SelectAllRow(
                                checked: provider.allVisibleSelected,
                                onTap: provider.toggleAllVisible,
                              ),
                            ],
                          ] else if (provider.families.isNotEmpty)
                            const _PlaceSwitch(),
                          if (provider.emptyMessage case final message?) ...[
                            const SizedBox(height: 12),
                            _EmptyCard(
                              message: message,
                              actionLabel:
                                  provider.emptyState ==
                                      FamiliesEmptyState.noSchool
                                  ? 'Add your kids’ school'
                                  : null,
                              onAction: () => Navigator.pushNamed(
                                context,
                                AppRoutes.whereKidsGo,
                              ).then((_) => provider.load()),
                            ),
                          ],
                          for (final family in provider.visibleFamilies) ...[
                            const SizedBox(height: 12),
                            FamilyListCard(
                              family: family,
                              selectable: selecting,
                              selected: provider.isSelected(family),
                              onTap: () => selecting
                                  ? provider.toggle(family)
                                  : provider.beginSelection(family),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (selecting)
                    _SelectActions(
                      canSayHi: provider.hasSelection,
                      onCancel: () => provider.startedInSelectMode
                          ? Navigator.of(context).maybePop()
                          : provider.cancelSelection(),
                      onSayHi: () => SendMessageSheet.show(
                        context,
                        provider: provider,
                        onSend: () => _send(context, provider.selectedCount),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _editRide(BuildContext context, FamiliesNearYouProvider provider) {
    if (provider.startedInSelectMode) {
      Navigator.of(context).maybePop();
    } else {
      Navigator.pushNamed(context, AppRoutes.askRide);
    }
  }

  void _send(BuildContext context, int parentCount) {
    final navigator = Navigator.of(context);
    navigator.pop(); // close the sheet
    // F20 reads the number of parents messaged from the route arguments.
    navigator.pushNamed(AppRoutes.messageSent, arguments: parentCount);
  }
}

class _PlaceSwitch extends StatelessWidget {
  const _PlaceSwitch();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FamiliesNearYouProvider>();
    return _ChipScroller(
      children: [
        HomePillChip.place(
          label: 'All · ${provider.totalCount}',
          selected: provider.placeId == null,
          onTap: () => provider.selectPlace(null),
        ),
        for (final place in provider.places)
          HomePillChip.place(
            label: '${place.name} · ${provider.countFor(place)}',
            icon: switch (place.kind) {
              KidPlaceKind.school => HomeAssets.iconSchool,
              KidPlaceKind.activity => HomeAssets.iconMusic,
            },
            selected: provider.placeId == place.id,
            onTap: () => provider.selectPlace(place.id),
          ),
      ],
    );
  }
}

/// Empty / error state: a surface card with the reason and, when the user
/// can fix it, a button.
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.message,
    required this.onAction,
    this.actionLabel,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusRow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: HomeTextStyles.bodyM),
          if (label != null) ...[
            const SizedBox(height: 12),
            AppButton(label: label, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FamiliesNearYouProvider>();
    return _ChipScroller(
      children: [
        for (final filter in FamilyFilter.values)
          HomePillChip.filter(
            label: filter.label,
            selected: provider.filter == filter,
            onTap: () => provider.setFilter(filter),
          ),
      ],
    );
  }
}

/// Horizontally scrolling chip row that bleeds to the screen edge.
class _ChipScroller extends StatelessWidget {
  const _ChipScroller({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final (i, chip) in children.indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            chip,
          ],
        ],
      ),
    );
  }
}

class _SelectAllRow extends StatelessWidget {
  const _SelectAllRow({required this.checked, required this.onTap});

  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: [
            SelectBox(checked: checked),
            const SizedBox(width: 10),
            Text('Select All', style: HomeTextStyles.selectAll),
          ],
        ),
      ),
    );
  }
}

class _SelectActions extends StatelessWidget {
  const _SelectActions({
    required this.canSayHi,
    required this.onCancel,
    required this.onSayHi,
  });

  final bool canSayHi;
  final VoidCallback onCancel;
  final VoidCallback onSayHi;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _PillAction(
              color: AppColors.surface,
              onTap: onCancel,
              child: Text('Cancel', style: AppTextStyles.label),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PillAction(
              color: AppColors.lime,
              onTap: canSayHi ? onSayHi : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(HomeAssets.iconCheck),
                  const SizedBox(width: 12),
                  Text('Say Hi', style: HomeTextStyles.buttonL),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 48px pill button used in the F14 action bar.
class _PillAction extends StatelessWidget {
  const _PillAction({
    required this.color,
    required this.onTap,
    required this.child,
  });

  final Color color;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: onTap == null ? 0.4 : 1,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: SizedBox(
            height: 48,
            child: Center(
              child: FittedBox(fit: BoxFit.scaleDown, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
