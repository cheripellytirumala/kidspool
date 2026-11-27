import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../common/core/services/maps_availability.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/theme/app_text_styles.dart';

/// "Map · Home preview" on S04: a light map with the home pin at [point]
/// (the located, picked or typed address). It follows the address as it
/// changes; tapping it opens the full map to move the pin.
class HomeMapPreview extends StatefulWidget {
  const HomeMapPreview({
    super.key,
    required this.label,
    this.point,
    this.onTap,
  });

  /// Address shown in the pill; hidden when empty.
  final String label;

  /// The home, or null while no address is known yet.
  final LatLng? point;

  /// Opens the full-screen map picker.
  final VoidCallback? onTap;

  @override
  State<HomeMapPreview> createState() => _HomeMapPreviewState();
}

class _HomeMapPreviewState extends State<HomeMapPreview> {
  static const double _height = 140;
  static const double _zoom = 15;

  bool? _mapAvailable;
  GoogleMapController? _map;

  @override
  void initState() {
    super.initState();
    MapsAvailability.isNativeMapConfigured().then((ok) {
      if (mounted) setState(() => _mapAvailable = ok);
    });
  }

  @override
  void didUpdateWidget(HomeMapPreview old) {
    super.didUpdateWidget(old);
    final point = widget.point;
    final map = _map;
    if (point != null && point != old.point && map != null) {
      // The map may have been taken down since (address being edited):
      // a stale controller throws, and the new map starts on the point.
      try {
        map
            .animateCamera(CameraUpdate.newLatLngZoom(point, _zoom))
            .catchError((Object _) {});
      } on StateError {
        _map = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.point;
    final Widget body;
    if (point != null && _mapAvailable == true) {
      body = IgnorePointer(
        // Gestures belong to the full map; this one is a preview.
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: point, zoom: _zoom),
          onMapCreated: (c) => _map = c,
          markers: {Marker(markerId: const MarkerId('home'), position: point)},
          liteModeEnabled: true,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: false,
          scrollGesturesEnabled: false,
          zoomGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
        ),
      );
    } else {
      // The GoogleMap (and its controller) is gone: forget the controller.
      _map = null;
      body = _Placeholder(hasAddress: point != null);
    }

    final map = ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusMap),
      child: SizedBox(
        height: _height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            body,
            if (widget.label.isNotEmpty)
              Positioned(
                left: 12,
                top: 12,
                right: 12,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                    decoration: BoxDecoration(
                      color: AppColors.screen,
                      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                      boxShadow: const [
                        BoxShadow(color: Color(0x22000000), blurRadius: 6),
                      ],
                    ),
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.onTap != null)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                  child: Text(
                    point == null ? 'Pick on map' : 'Move pin',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textOnDark,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    final onTap = widget.onTap;
    if (onTap == null) return map;
    return Semantics(
      button: true,
      label: point == null
          ? 'Pick your home on the map'
          : 'Move your home pin on the map',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: map,
      ),
    );
  }
}

/// Light placeholder while there's no address (or no map key).
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.hasAddress});

  final bool hasAddress;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.home_outlined,
                size: 28,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 6),
              Text(
                hasAddress
                    ? 'Map isn’t available right now'
                    : 'Type your address or use your location to see it here',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
