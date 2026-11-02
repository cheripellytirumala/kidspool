import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_badge.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/kids_assets.dart';
import '../../core/constants/kids_styles.dart';
import '../../domain/entities/place.dart';
import '../providers/kids_provider.dart';
import '../providers/place_search_provider.dart';
import '../widgets/icon_disc.dart';
import '../widgets/kid_avatar.dart';
import '../widgets/kids_scaffold.dart';
import '../widgets/kids_sheet.dart';
import '../widgets/place_result_tile.dart';
import '../../../common/presentation/widgets/app_loader.dart';

/// F09 · Find & join a school.
///
/// The page offers "Add a school" / "Add an activity"; both open the
/// "Add school & activity" sheet — Figma 1018:8635 (School tab, results)
/// and 1018:8797 (Activity tab, a selected club). The picked place goes to
/// F10 to choose who goes there.
class FindSchoolScreen extends StatelessWidget {
  const FindSchoolScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<KidsProvider>.value(value: sl<KidsProvider>()),
        ChangeNotifierProvider<PlaceSearchProvider>(
          create: (_) => sl<PlaceSearchProvider>(),
        ),
      ],
      child: const _FindSchoolView(),
    );
  }
}

class _FindSchoolView extends StatelessWidget {
  const _FindSchoolView();

  static const _activities = [
    (PlaceCategory.soccer, KidsAssets.soccer14, 'Soccer'),
    (PlaceCategory.swim, KidsAssets.swim14, 'Swim'),
    (PlaceCategory.music, KidsAssets.music14, 'Music'),
    (PlaceCategory.dance, KidsAssets.dance14, 'Dance'),
  ];

  Future<void> _openSheet(
    BuildContext context,
    PlaceKind kind, {
    String query = '',
  }) {
    final kids = context.read<KidsProvider>();
    final search = context.read<PlaceSearchProvider>()
      ..open(kind, query: query);
    final media = MediaQuery.of(context);
    // Figma: the sheet starts 30px below the status bar.
    final height = media.size.height - media.padding.top - 30;

    return showKidsSheet<void>(
      context,
      (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider<KidsProvider>.value(value: kids),
          ChangeNotifierProvider<PlaceSearchProvider>.value(value: search),
        ],
        child: _PlaceSearchSheet(height: height),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kids = context.watch<KidsProvider>();
    final pending = kids.pendingPlace;

    return AppLoadingOverlay(
      isLoading: kids.isLoading,
      child: KidsScaffold(
        trailing: const AppBadge(
          label: 'Step 3 of 3',
          background: AppColors.surface,
          foreground: AppColors.textPrimary,
          showDot: false,
        ),
        topPadding: 4,
        gap: 12,
        title: 'Where do your kids go?',
        subtitle:
            'Add each school and activity once — then tick which kids go '
            'there.',
        bottom: AppButton(
          label: 'Continue',
          onPressed: pending == null
              ? null
              : () => Navigator.of(context).pushNamed(AppRoutes.whoGoesWhen),
        ),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final child in kids.children)
                Container(
                  padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
                  decoration: const ShapeDecoration(
                    color: AppColors.surface,
                    shape: StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      KidAvatar(child: child, size: 32),
                      Text(
                        '${child.firstName} · '
                        '${kids.placesCountLabel(child.id)}',
                        style: KidsTextStyles.captionM.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          _AddCard(
            color: AppColors.lime,
            title: 'Add a school',
            subtitle: pending?.kind == PlaceKind.school
                ? 'Selected: ${pending!.name}'
                : 'From the official US school list',
            icon: const IconDisc(
              asset: KidsAssets.grad25,
              size: 52,
              iconSize: 25,
              color: AppColors.ink,
            ),
            action: const IconDisc(
              asset: KidsAssets.plus18,
              size: 36,
              iconSize: 18,
              color: AppColors.screen,
            ),
            onTap: () => _openSheet(context, PlaceKind.school),
          ),
          _AddCard(
            color: AppColors.inverse,
            dark: true,
            title: 'Add an activity',
            subtitle: pending?.kind == PlaceKind.activity
                ? 'Selected: ${pending!.name}'
                : 'Clubs, classes & lessons near you',
            icon: const IconDisc(
              asset: KidsAssets.ball25,
              size: 52,
              iconSize: 25,
              color: AppColors.lime,
            ),
            action: const IconDisc(
              asset: KidsAssets.plus18,
              size: 36,
              iconSize: 18,
              color: KidsColors.charcoal,
              iconColor: AppColors.textOnDark,
            ),
            onTap: () => _openSheet(context, PlaceKind.activity),
            footer: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (category, icon, label) in _activities)
                  _ActivityChip(
                    icon: icon,
                    label: label,
                    onTap: () => _openSheet(
                      context,
                      PlaceKind.activity,
                      query: category.name,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              spacing: 12,
              children: [
                const IconDisc(
                  asset: KidsAssets.people17,
                  size: 36,
                  iconSize: 17,
                  color: AppColors.screen,
                ),
                Expanded(
                  child: Text(
                    'Siblings at the same school or club? Add it once and tick '
                    'both kids.',
                    style: KidsTextStyles.bodyS,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Row(
              spacing: 10,
              children: [
                const AppIcon(KidsAssets.shield16, size: 16),
                Expanded(
                  child: Text(
                    'Why we ask: rides are only shared with families going to '
                    'the same places.',
                    style: KidsTextStyles.captionM,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Add · School" (lime) and "Add · Activity" (ink) cards.
class _AddCard extends StatelessWidget {
  const _AddCard({
    required this.color,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.action,
    required this.onTap,
    this.dark = false,
    this.footer,
  });

  final Color color;
  final String title;
  final String subtitle;
  final Widget icon;
  final Widget action;
  final VoidCallback onTap;
  final bool dark;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Row(
                spacing: 14,
                children: [
                  icon,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.headingH3.copyWith(
                            color: dark
                                ? AppColors.textOnDark
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: KidsTextStyles.captionM.copyWith(
                            color: dark
                                ? AppColors.textOnDarkMuted
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  action,
                ],
              ),
              ?footer,
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityChip extends StatelessWidget {
  const _ActivityChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KidsColors.charcoal,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              AppIcon(icon, size: 14),
              Text(
                label,
                style: KidsTextStyles.captionM.copyWith(
                  color: AppColors.textOnDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Add school & activity" sheet: School/Activity switch, search field and
/// results (schools from `get_schools`, activities from the local catalog).
class _PlaceSearchSheet extends StatefulWidget {
  const _PlaceSearchSheet({required this.height});

  final double height;

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  late final TextEditingController _query = TextEditingController(
    text: context.read<PlaceSearchProvider>().query,
  );

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _select(Place place) async {
    final kids = context.read<KidsProvider>();
    if (place.kind == PlaceKind.school) {
      kids.rememberSchools(context.read<PlaceSearchProvider>().results);
    }
    if (kids.pendingPlace?.id == place.id) {
      kids.setPendingPlace(null);
      return;
    }
    kids.setPendingPlace(place);
    // Let the selected state show before closing.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<PlaceSearchProvider>();
    final selectedId = context.watch<KidsProvider>().pendingPlace?.id;
    final results = search.results;

    return KidsSheet(
      height: widget.height,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Add school & activity',
                style: KidsTextStyles.headingH2,
              ),
            ),
            const KidsSheetCloseButton(),
          ],
        ),
        _KindSwitch(value: search.kind, onChanged: search.setKind),
        _SearchField(
          controller: _query,
          onChanged: search.setQuery,
          onClear: () {
            _query.clear();
            search.setQuery('');
          },
        ),
        Expanded(
          child: search.isSearching && results.isEmpty
              ? const Center(child: AppLoader(size: 56))
              : results.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    search.errorMessage ??
                        'No matches. Try another name or city.',
                    textAlign: TextAlign.center,
                    style: KidsTextStyles.captionM,
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => PlaceResultTile(
                    place: results[i],
                    selected: results[i].id == selectedId,
                    onTap: () => _select(results[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

/// "Kind" segmented control.
class _KindSwitch extends StatelessWidget {
  const _KindSwitch({required this.value, required this.onChanged});

  final PlaceKind value;
  final ValueChanged<PlaceKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const ShapeDecoration(
        color: AppColors.surface,
        shape: StadiumBorder(),
      ),
      child: Row(
        spacing: 4,
        children: [
          for (final (kind, icon, label) in const [
            (PlaceKind.school, KidsAssets.grad16, 'School'),
            (PlaceKind.activity, KidsAssets.ball16, 'Activity'),
          ])
            Expanded(
              child: _KindSegment(
                icon: icon,
                label: label,
                selected: kind == value,
                onTap: () => onChanged(kind),
              ),
            ),
        ],
      ),
    );
  }
}

class _KindSegment extends StatelessWidget {
  const _KindSegment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.ink : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8,
              children: [
                AppIcon(
                  icon,
                  size: 16,
                  color: selected ? AppColors.lime : AppColors.ink,
                ),
                Text(
                  label,
                  style: KidsTextStyles.labelM.copyWith(
                    color: selected
                        ? AppColors.textOnDark
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Search" pill: 2px ink border, search icon, clear button.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.ink, width: 2),
        ),
      ),
      child: Row(
        spacing: 10,
        children: [
          const AppIcon(KidsAssets.search, size: 20),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: KidsTextStyles.labelL,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search with Names or Zip Code',
                hintStyle: KidsTextStyles.labelL.copyWith(
                  color: AppColors.textPrimary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Clear search',
            child: GestureDetector(
              onTap: onClear,
              child: IconDisc(
                asset: KidsAssets.close,
                size: 24,
                iconSize: 12,
                color: AppColors.surfaceStrong,
                border: Border.all(color: AppColors.borderField, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
