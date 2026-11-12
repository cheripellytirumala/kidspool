import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/widgets/app_select_card.dart';
import '../../core/constants/ask_ride_assets.dart';
import '../../domain/entities/saved_place.dart';
import '../providers/drop_off_search_provider.dart';
import 'ask_ride_sheet.dart';
import 'ask_ride_text_styles.dart';
import 'place_picker_sheet.dart';

/// Tabs of the "Drop off at" sheet.
enum DropOffTab { schools, search }

/// "Drop off at": **Schools** (the kids' schools) or **Search location**
/// (any place, address or zip code from Google). Pops with [PlacePicked]
/// for a school or [CustomPlacePicked] for a search result.
///
/// Needs a [DropOffSearchProvider] above it.
class DropOffPickerSheet extends StatefulWidget {
  const DropOffPickerSheet({
    super.key,
    required this.schools,
    required this.selected,
    this.emptyMessage,
    this.title = 'Drop off at',
    this.activities = const [],
  });

  /// The selected kids' activities (soccer, music…), listed under the
  /// schools; picking one drops off at that place.
  final List<SavedPlace> activities;

  /// "Pick up from" when the ride goes from the school back home.
  final String title;

  final List<SavedPlace> schools;
  final SavedPlace? selected;

  /// Shown on the Schools tab when [schools] is empty.
  final String? emptyMessage;

  @override
  State<DropOffPickerSheet> createState() => _DropOffPickerSheetState();
}

class _DropOffPickerSheetState extends State<DropOffPickerSheet> {
  late DropOffTab _tab =
      (widget.selected?.isCustom ?? false) &&
          !widget.activities.contains(widget.selected)
      ? DropOffTab.search
      : DropOffTab.schools;
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fixed height so switching tabs or getting results doesn't resize it.
    final height = MediaQuery.sizeOf(context).height * 0.75;
    return SizedBox(
      height: height,
      child: AskRideSheet(
        title: widget.title,
        children: [
          DropOffTabs(
            value: _tab,
            onChanged: (tab) {
              if (tab == _tab) return;
              FocusScope.of(context).unfocus();
              setState(() => _tab = tab);
            },
          ),
          ...switch (_tab) {
            DropOffTab.schools => _schools(context),
            DropOffTab.search => _search(context),
          },
        ],
      ),
    );
  }

  List<Widget> _schools(BuildContext context) => [
    for (final place in widget.schools)
      AppSelectCard(
        title: place.name,
        subtitle: [place.address, ?place.detail].join(' · '),
        icon: savedPlaceIcon(place.kind),
        selected: place == widget.selected,
        onTap: () => Navigator.of(context).pop(PlacePicked(place)),
      ),
    if (widget.schools.isEmpty &&
        widget.activities.isEmpty &&
        widget.emptyMessage != null)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(widget.emptyMessage!, style: AppTextStyles.bodyL),
      ),
    if (widget.activities.isNotEmpty) ...[
      Padding(
        padding: const EdgeInsets.only(top: 8, left: 4),
        child: Text('ACTIVITIES', style: AskRideTextStyles.fieldCaption),
      ),
      for (final place in widget.activities)
        AppSelectCard(
          title: place.name,
          subtitle: [place.address, ?place.detail].join(' · '),
          icon: savedPlaceIcon(PlaceKind.custom),
          selected: place == widget.selected,
          onTap: () => Navigator.of(context).pop(CustomPlacePicked(place)),
        ),
    ],
  ];

  List<Widget> _search(BuildContext context) {
    final search = context.watch<DropOffSearchProvider>();
    final selected = widget.selected;
    final results = search.results;
    return [
      DropOffSearchField(
        controller: _query,
        onChanged: search.setQuery,
        onClear: () {
          _query.clear();
          search.setQuery('');
        },
      ),
      if (search.isIdle)
        _Hint(
          selected != null && selected.isCustom
              ? 'Now: ${selected.name}. Type to pick another place.'
              : 'Type a place name, an address or a zip code.',
        )
      else if (search.isSearching && results.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 24),
          child: Center(child: AppLoader(size: 56)),
        )
      else if (results.isEmpty)
        _Hint(search.errorMessage ?? 'No matches. Try another name or zip.')
      else
        for (final place in results)
          AppSelectCard(
            title: place.name,
            subtitle: place.address.isEmpty ? null : place.address,
            icon: savedPlaceIcon(PlaceKind.custom),
            selected:
                selected != null &&
                selected.isCustom &&
                (selected.id == place.id ||
                    (selected.latitude == place.latitude &&
                        selected.longitude == place.longitude)),
            onTap: () => Navigator.of(context).pop(CustomPlacePicked(place)),
          ),
    ];
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AskRideTextStyles.fieldCaption,
      ),
    );
  }
}

/// Segmented "Schools | Search location" switch (black selected pill, as
/// in the "Add school & activity" sheet).
class DropOffTabs extends StatelessWidget {
  const DropOffTabs({super.key, required this.value, required this.onChanged});

  final DropOffTab value;
  final ValueChanged<DropOffTab> onChanged;

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
          for (final (tab, icon, label) in const [
            (DropOffTab.schools, AskRideAssets.schoolSmall, 'Schools'),
            (DropOffTab.search, AppAssets.iconSearch, 'Search location'),
          ])
            Expanded(
              child: _TabSegment(
                icon: icon,
                label: label,
                selected: tab == value,
                onTap: () => onChanged(tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabSegment extends StatelessWidget {
  const _TabSegment({
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
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AskRideTextStyles.labelM.copyWith(
                      color: selected
                          ? AppColors.textOnDark
                          : AppColors.textPrimary,
                    ),
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
class DropOffSearchField extends StatelessWidget {
  const DropOffSearchField({
    super.key,
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
      decoration: const ShapeDecoration(
        color: AppColors.surface,
        shape: StadiumBorder(side: BorderSide(color: AppColors.ink, width: 2)),
      ),
      child: Row(
        spacing: 10,
        children: [
          const AppIcon(AppAssets.iconSearch, size: 20),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              autofocus: true,
              textInputAction: TextInputAction.search,
              style: AskRideTextStyles.labelL,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search a place, address or zip code',
                hintStyle: AskRideTextStyles.labelL.copyWith(
                  color: AppColors.textPrimary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Clear search',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onClear,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceStrong,
                  shape: BoxShape.circle,
                ),
                child: const AppIcon(AskRideAssets.close, size: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
