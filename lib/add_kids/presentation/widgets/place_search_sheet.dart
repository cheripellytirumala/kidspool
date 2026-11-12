import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../core/constants/kids_assets.dart';
import '../../core/constants/kids_styles.dart';
import '../../domain/entities/place.dart';
import '../providers/kids_provider.dart';
import '../providers/place_search_provider.dart';
import 'icon_disc.dart';
import 'kids_sheet.dart';
import 'place_result_tile.dart';

/// Opens F09 · "Add school & activity" (Figma 849:13899 School tab,
/// 852:14790 Activity tab) over the current page. Completes with the picked
/// place (also set as [KidsProvider.pendingPlace]), or `null` when closed.
Future<Place?> showPlaceSearchSheet(
  BuildContext context, {
  PlaceKind kind = PlaceKind.school,
}) {
  final kids = context.read<KidsProvider>();
  final media = MediaQuery.of(context);
  // Figma: the sheet starts 30px below the status bar (760 of 844).
  final height = media.size.height - media.padding.top - 30;

  return showKidsSheet<Place>(
    context,
    (_) => MultiProvider(
      providers: [
        ChangeNotifierProvider<KidsProvider>.value(value: kids),
        ChangeNotifierProvider<PlaceSearchProvider>(
          create: (_) => sl<PlaceSearchProvider>()..open(kind),
        ),
      ],
      child: PlaceSearchSheet(height: height),
    ),
  );
}

/// "Add school & activity" sheet: School/Activity switch, search field and
/// results (schools and activities from Google Places Text Search).
class PlaceSearchSheet extends StatefulWidget {
  const PlaceSearchSheet({super.key, required this.height});

  final double height;

  @override
  State<PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<PlaceSearchSheet> {
  late final TextEditingController _query = TextEditingController(
    text: context.read<PlaceSearchProvider>().query,
  );
  bool _closing = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _select(Place place) async {
    if (_closing) return;
    _closing = true;
    context.read<KidsProvider>().setPendingPlace(place);
    // Let the selected state show before F10 replaces this sheet.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) Navigator.of(context).pop(place);
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
                  itemCount: results.length + (search.canSearchGoogle ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => i == results.length
                      // Results are from KidPool's list: the place may
                      // still be new.
                      ? TextButton.icon(
                          onPressed: search.searchGoogle,
                          icon: const Icon(Icons.search_rounded, size: 18),
                          label: Text(
                            'Can’t find it? Search Google',
                            style: KidsTextStyles.captionM,
                          ),
                        )
                      : PlaceResultTile(
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
