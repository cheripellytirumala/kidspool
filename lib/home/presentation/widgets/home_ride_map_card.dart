import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../core/constants/home_assets.dart';
import '../../core/constants/home_text_styles.dart';

/// H3 "Map" card: a decorative dark map with the route from pickup to
/// [destination], a chip saying who drives whom, the pickup time and a
/// white "Track" button. The map is static artwork (no platform view).
class HomeRideMapCard extends StatelessWidget {
  const HomeRideMapCard({
    super.key,
    required this.headline,
    required this.avatarInitials,
    required this.destination,
    required this.pickupLabel,
    required this.onTrack,
    this.avatarUrl,
  });

  /// "Jen drives Emma"
  final String headline;
  final String avatarInitials;
  final String? avatarUrl;

  /// "Lincoln" — label above the destination pin.
  final String destination;

  /// "Home · 8:30 AM"
  final String pickupLabel;
  final VoidCallback onTrack;

  /// Figma frame the route artwork was drawn in.
  static const Size _designSize = Size(354, 220);
  static const double _radius = 36;

  /// bg/inverse-raised.
  static const Color _chipColor = Color(0xFF1C1C1C);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_radius);
    return Semantics(
      button: true,
      label: '$headline. $pickupLabel to $destination. Track',
      excludeSemantics: true,
      child: Material(
        color: AppColors.inverse,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTrack,
          child: SizedBox(
            height: _designSize.height,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Map/Dark tile, offset as in the design.
                Positioned(
                  left: -250,
                  top: -330,
                  width: 800,
                  height: 900,
                  child: SvgPicture.asset(
                    AppAssets.mapDark,
                    width: 800,
                    height: 900,
                  ),
                ),
                // Route, pins and car marker: scaled down with the card on
                // narrow screens, never up.
                Positioned.fill(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: SizedBox.fromSize(
                      size: _designSize,
                      child: _RouteLayer(destination: destination),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 16,
                  right: 16,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _DriverChip(
                      headline: headline,
                      initials: avatarInitials,
                      photoUrl: avatarUrl,
                    ),
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 112,
                  top: 186,
                  child: Text(
                    pickupLabel,
                    style: HomeTextStyles.mapCaption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 16,
                  child: _TrackButton(onPressed: onTrack),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteLayer extends StatelessWidget {
  const _RouteLayer({required this.destination});

  final String destination;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 18,
          top: 20,
          child: SvgPicture.asset(HomeAssets.route, width: 258, height: 154),
        ),
        Positioned(
          left: 37,
          top: 163,
          child: SvgPicture.asset(HomeAssets.routeStart, width: 14, height: 14),
        ),
        // Pin · destination
        Positioned(
          left: 202,
          top: 4,
          width: 140,
          child: Text(
            destination,
            style: HomeTextStyles.mapPin,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Positioned(
          left: 255,
          top: 24,
          width: 34,
          height: 34,
          child: Center(
            child: SvgPicture.asset(
              HomeAssets.pin,
              width: 19.8333,
              height: 28.3333,
            ),
          ),
        ),
        // Car marker
        Positioned(
          left: 3,
          top: 56,
          child: Container(
            width: 35,
            height: 35,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.lime,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.inverse, width: 4),
              boxShadow: AppDimens.buttonGlow,
            ),
            child: SvgPicture.asset(
              HomeAssets.iconCar,
              width: 17.4167,
              height: 13.4269,
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverChip extends StatelessWidget {
  const _DriverChip({
    required this.headline,
    required this.initials,
    required this.photoUrl,
  });

  final String headline;
  final String initials;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.lime,
        shape: BoxShape.circle,
      ),
      child: Text(initials, style: HomeTextStyles.labelM, maxLines: 1),
    );
    final url = photoUrl;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      decoration: BoxDecoration(
        color: HomeRideMapCard._chipColor,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (url == null || url.isEmpty)
            fallback
          else
            ClipOval(
              child: Image.network(
                url,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              headline,
              style: HomeTextStyles.mapChip,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackButton extends StatelessWidget {
  const _TrackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.screen,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              widthFactor: 1,
              child: Text('Track', style: HomeTextStyles.mapButton),
            ),
          ),
        ),
      ),
    );
  }
}
