import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/widgets/app_select_card.dart';
import '../../core/constants/ask_ride_assets.dart';
import '../../domain/entities/saved_place.dart';
import '../providers/drop_off_search_provider.dart';
import 'ask_ride_sheet.dart';
import 'ask_ride_text_styles.dart';
import 'place_picker_sheet.dart';

/// What the "Drop off at" sheet shows: the saved places, or the search
/// for a new one.
enum DropOffMode { saved, addNew }

/// "Drop off at": the **saved places** (the kids' schools, then their
/// activities and places picked before) and an **Add new location** button
/// that searches any place, address or zip code with Google. Pops with
/// [PlacePicked] for a school or [CustomPlacePicked] for any other place.
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

  /// The selected kids' activities and saved places, listed after the
  /// schools; picking one drops off at that place.
  final List<SavedPlace> activities;

  /// "Pick up from" when the ride goes from the school back home.
  final String title;

  final List<SavedPlace> schools;
  final SavedPlace? selected;

  /// Shown when there are no saved places yet.
  final String? emptyMessage;

  @override
  State<DropOffPickerSheet> createState() => _DropOffPickerSheetState();
}

class _DropOffPickerSheetState extends State<DropOffPickerSheet> {
  DropOffMode _mode = DropOffMode.saved;
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _setMode(DropOffMode mode) {
    if (mode == _mode) return;
    FocusScope.of(context).unfocus();
    setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    // Fixed height so switching or getting results doesn't resize it.
    final height = MediaQuery.sizeOf(context).height * 0.75;
    return SizedBox(
      height: height,
      child: AskRideSheet(
        title: widget.title,
        children: [
          AddLocationButton(
            mode: _mode,
            onTap: () => _setMode(
              _mode == DropOffMode.saved
                  ? DropOffMode.addNew
                  : DropOffMode.saved,
            ),
          ),
          ...switch (_mode) {
            DropOffMode.saved => _saved(context),
            DropOffMode.addNew => _search(context),
          },
        ],
      ),
    );
  }

  List<Widget> _saved(BuildContext context) {
    final selected = widget.selected;
    final saved = [...widget.schools, ...widget.activities];
    return [
      for (final place in widget.schools)
        AppSelectCard(
          title: place.name,
          subtitle: [place.address, ?place.detail].join(' · '),
          icon: savedPlaceIcon(place.kind),
          selected: place == selected,
          onTap: () => Navigator.of(context).pop(PlacePicked(place)),
        ),
      for (final place in widget.activities)
        AppSelectCard(
          title: place.name,
          subtitle: [place.address, ?place.detail].join(' · '),
          icon: savedPlaceIcon(PlaceKind.custom),
          selected: place == selected,
          onTap: () => Navigator.of(context).pop(CustomPlacePicked(place)),
        ),
      // A searched place that couldn't be saved (no kid picked) stays
      // visible as the current choice.
      if (selected != null && selected.isCustom && !saved.contains(selected))
        AppSelectCard(
          title: selected.name,
          subtitle: selected.address.isEmpty ? null : selected.address,
          icon: savedPlaceIcon(PlaceKind.custom),
          selected: true,
          onTap: () => Navigator.of(context).pop(CustomPlacePicked(selected)),
        ),
      if (saved.isEmpty && widget.emptyMessage != null)
        _Hint(widget.emptyMessage!),
    ];
  }

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
        const _Hint(
          'Type a place name, an address or a zip code. It’s saved with '
          'your members’ places.',
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

/// Top of the "Drop off at" sheet: **Add new location** (black pill)
/// opens the search; on the search it turns into **Saved locations** to go
/// back to the list.
class AddLocationButton extends StatelessWidget {
  const AddLocationButton({super.key, required this.mode, required this.onTap});

  final DropOffMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final adding = mode == DropOffMode.addNew;
    return Semantics(
      button: true,
      child: Material(
        color: adding ? AppColors.surface : AppColors.ink,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8,
              children: [
                Icon(
                  adding ? Icons.arrow_back_rounded : Icons.add_rounded,
                  size: 20,
                  color: adding ? AppColors.ink : AppColors.lime,
                ),
                Text(
                  adding ? 'Saved locations' : 'Add new location',
                  style: AskRideTextStyles.labelM.copyWith(
                    color: adding
                        ? AppColors.textPrimary
                        : AppColors.textOnDark,
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
