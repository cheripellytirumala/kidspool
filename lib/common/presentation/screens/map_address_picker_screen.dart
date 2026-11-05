import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../../core/di/injection_container.dart';
import '../../core/services/maps_availability.dart';
import '../../domain/entities/picked_address.dart';
import '../../domain/entities/place_suggestion.dart';
import '../providers/map_address_picker_provider.dart';
import '../theme/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/app_icon.dart';
import '../widgets/app_loader.dart';

/// Full-screen Google map with a search field. The user searches an address
/// (Places autocomplete) or drags the map under the pin, then confirms.
///
/// Returns the chosen [PickedAddress], or `null` if dismissed.
class MapAddressPickerScreen extends StatelessWidget {
  const MapAddressPickerScreen({
    super.key,
    this.title = 'Choose an address',
    this.confirmLabel = 'Use this address',
    this.initial,
  });

  final String title;
  final String confirmLabel;

  /// Where the map opens; defaults to the device location.
  final PickedAddress? initial;

  static Future<PickedAddress?> open(
    BuildContext context, {
    String title = 'Choose an address',
    String confirmLabel = 'Use this address',
    PickedAddress? initial,
  }) {
    return Navigator.of(context).push<PickedAddress>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MapAddressPickerScreen(
          title: title,
          confirmLabel: confirmLabel,
          initial: initial,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => sl<MapAddressPickerProvider>(),
      child: _MapAddressPickerView(
        title: title,
        confirmLabel: confirmLabel,
        initial: initial,
      ),
    );
  }
}

class _MapAddressPickerView extends StatefulWidget {
  const _MapAddressPickerView({
    required this.title,
    required this.confirmLabel,
    this.initial,
  });

  final String title;
  final String confirmLabel;
  final PickedAddress? initial;

  @override
  State<_MapAddressPickerView> createState() => _MapAddressPickerViewState();
}

class _MapAddressPickerViewState extends State<_MapAddressPickerView> {
  // Shown until the device location (or [initial]) is known.
  static const _fallback = CameraPosition(target: LatLng(20, 0), zoom: 2);
  static const double _addressZoom = 17;

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  GoogleMapController? _map;
  LatLng? _cameraTarget;
  bool _movedByUser = false;

  /// `null` while checking; `false` when no native Maps key is set (showing a
  /// map would crash on iOS), so search + location work without the map.
  bool? _mapAvailable;

  MapAddressPickerProvider get _provider =>
      context.read<MapAddressPickerProvider>();

  @override
  void initState() {
    super.initState();
    MapsAvailability.isNativeMapConfigured().then((ok) {
      if (mounted) setState(() => _mapAvailable = ok);
    });
    _searchFocus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initial = widget.initial;
      if (initial != null) {
        await _provider.onMapSettled(initial.latitude, initial.longitude);
      } else {
        await _goToMyLocation();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _moveTo(PickedAddress address) async {
    _movedByUser = false;
    await _map?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(address.latitude, address.longitude),
        _addressZoom,
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    final here = await _provider.useMyLocation();
    if (here != null && mounted) await _moveTo(here);
  }

  Future<void> _select(PlaceSuggestion suggestion) async {
    _searchFocus.unfocus();
    _searchController.text = suggestion.primaryText;
    final picked = await _provider.selectSuggestion(suggestion);
    if (picked != null && mounted) await _moveTo(picked);
  }

  void _onCameraIdle() {
    final target = _cameraTarget;
    if (target == null || !_movedByUser) return;
    _movedByUser = false;
    _provider.onMapSettled(target.latitude, target.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MapAddressPickerProvider>();
    final showSuggestions =
        _searchFocus.hasFocus && provider.query.trim().length >= 3;
    final initial = widget.initial;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            if (_mapAvailable != true)
              Positioned.fill(
                child: _MapUnavailableBackground(
                  checking: _mapAvailable == null,
                ),
              )
            else ...[
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: initial == null
                      ? _fallback
                      : CameraPosition(
                          target: LatLng(initial.latitude, initial.longitude),
                          zoom: _addressZoom,
                        ),
                  onMapCreated: (c) => _map = c,
                  onCameraMoveStarted: () => _movedByUser = true,
                  onCameraMove: (p) => _cameraTarget = p.target,
                  onCameraIdle: _onCameraIdle,
                  onTap: (_) => _searchFocus.unfocus(),
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  // Leave room for the search bar and the address card.
                  padding: const EdgeInsets.only(top: 120, bottom: 220),
                ),
              ),
              // Pin sits at the map centre (shifted by the map padding).
              const Positioned.fill(
                top: 120,
                bottom: 220,
                child: IgnorePointer(child: Center(child: _CenterPin())),
              ),
            ],
            Positioned(
              left: AppDimens.screenPadding,
              right: AppDimens.screenPadding,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          _RoundButton(
                            asset: AppAssets.iconArrowLeft,
                            tooltip: 'Back',
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SearchField(
                              controller: _searchController,
                              focusNode: _searchFocus,
                              hint: 'Search an address',
                              isSearching: provider.isSearching,
                              onChanged: provider.onQueryChanged,
                              onClear: () {
                                _searchController.clear();
                                provider.clearSearch();
                              },
                            ),
                          ),
                        ],
                      ),
                      if (showSuggestions)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _SuggestionList(
                            suggestions: provider.suggestions,
                            isSearching: provider.isSearching,
                            error: provider.searchError,
                            onSelect: _select,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _AddressCard(
                address: provider.address,
                isResolving: provider.isResolving,
                error: provider.error,
                confirmLabel: widget.confirmLabel,
                onMyLocation: _goToMyLocation,
                onConfirm: provider.canConfirm
                    ? () => Navigator.of(context).pop(provider.address)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lime home pin from the design ("Home pin"), tip on the map centre.
class _CenterPin extends StatelessWidget {
  const _CenterPin();

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.lime,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: 3),
              boxShadow: AppDimens.buttonGlow,
            ),
            child: const AppIcon(AppAssets.iconHome, size: 20),
          ),
          Container(width: 3, height: 10, color: AppColors.ink),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.asset,
    required this.tooltip,
    required this.onTap,
  });

  final String asset;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.screen,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: const Color(0x33000000),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 52,
            child: Center(child: AppIcon(asset, size: 22)),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.isSearching,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool isSearching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 18, right: 8),
      decoration: BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: focusNode.hasFocus
            ? Border.all(color: AppColors.ink, width: 2)
            : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const AppIcon(AppAssets.iconSearch, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: AppTextStyles.bodyL,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppTextStyles.bodyL.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          if (isSearching)
            const Padding(
              padding: EdgeInsets.all(8),
              child: AppLoader.glyph(size: 20),
            )
          else if (controller.text.isNotEmpty)
            IconButton(
              onPressed: onClear,
              tooltip: 'Clear',
              icon: const AppIcon(AppAssets.iconClose, size: 18),
            ),
        ],
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({
    required this.suggestions,
    required this.isSearching,
    required this.error,
    required this.onSelect,
  });

  final List<PlaceSuggestion> suggestions;
  final bool isSearching;
  final String? error;
  final ValueChanged<PlaceSuggestion> onSelect;

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (error != null) {
      content = _Message(error!);
    } else if (suggestions.isEmpty) {
      content = _Message(isSearching ? 'Searching…' : 'No matching addresses');
    } else {
      content = ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          indent: 56,
          color: AppColors.surfaceStrong,
        ),
        itemBuilder: (_, i) {
          final s = suggestions[i];
          return ListTile(
            onTap: () => onSelect(s),
            leading: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const AppIcon(AppAssets.iconLocate, size: 16),
            ),
            title: Text(
              s.primaryText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.title,
            ),
            subtitle: s.secondaryText.isEmpty
                ? null
                : Text(
                    s.secondaryText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
          );
        },
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.45,
      ),
      child: Material(
        color: AppColors.screen,
        elevation: 4,
        shadowColor: const Color(0x33000000),
        borderRadius: BorderRadius.circular(AppDimens.radiusRow),
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Text(text, style: AppTextStyles.caption),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.isResolving,
    required this.error,
    required this.confirmLabel,
    required this.onMyLocation,
    required this.onConfirm,
  });

  final PickedAddress? address;
  final bool isResolving;
  final String? error;
  final String confirmLabel;
  final VoidCallback onMyLocation;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final picked = address;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, AppDimens.screenPadding, 12),
          child: _RoundButton(
            asset: AppAssets.iconLocate,
            tooltip: 'Use my current location',
            onTap: onMyLocation,
          ),
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            AppDimens.screenPadding,
            20,
            AppDimens.screenPadding,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: const BoxDecoration(
            color: AppColors.screen,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDimens.radiusMap),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('PIN LOCATION', style: AppTextStyles.caption),
              const SizedBox(height: 6),
              SizedBox(
                height: 48,
                child: isResolving
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: AppLoader.glyph(size: 24),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            picked?.title ??
                                error ??
                                'Move the map or search an address',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.title,
                          ),
                          if (picked != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              picked.isComplete
                                  ? picked.subtitle
                                  : 'Move the pin onto a street address',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              AppButton(label: confirmLabel, onPressed: onConfirm),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shown instead of the map when the native Google Maps key isn't set:
/// the design's map artwork, dimmed, with a hint to search instead.
class _MapUnavailableBackground extends StatelessWidget {
  const _MapUnavailableBackground({required this.checking});

  final bool checking;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.mapDark,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.6,
            child: SvgPicture.asset(AppAssets.mapDark, fit: BoxFit.cover),
          ),
          if (!checking)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Map view isn’t set up on this build.\n'
                  'Search an address or use your current location.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
