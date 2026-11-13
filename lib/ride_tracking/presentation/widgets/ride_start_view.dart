import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/ride_tracking_assets.dart';
import '../../core/utils/ride_format.dart';
import '../../domain/entities/ride_tracking.dart';
import 'ride_avatar.dart';
import 'ride_buttons.dart';
import 'ride_map.dart';
import 'ride_styles.dart';

/// F20 · The Ride Partner's view before the ride starts: headline, a map
/// card to the destination, the kids, Message / Call and Start ride.
class RideStartView extends StatelessWidget {
  const RideStartView({
    super.key,
    required this.tracking,
    required this.busy,
    required this.onStart,
    required this.onMessage,
    required this.onCall,
    required this.onBack,
  });

  final RideTracking tracking;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onMessage;
  final VoidCallback onCall;

  /// Back to the dashboard (the tab under the ride pages).
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = tracking;
    final parentName = t.parent?.firstName ?? 'the parent';
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.screen,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: RideIconButton.back(onPressed: onBack),
                      ),
                      const SizedBox(height: 16),
                      _Headline(tracking: t),
                      const SizedBox(height: 12),
                      _MapCard(tracking: t),
                      const SizedBox(height: 12),
                      _KidsCard(tracking: t, parentName: parentName),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionPill(
                              icon: RideTrackingAssets.chat,
                              label: 'Message $parentName',
                              onTap: onMessage,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionPill(
                              icon: RideTrackingAssets.phone,
                              label: 'Call',
                              semanticLabel: 'Call $parentName',
                              onTap: onCall,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Start ride',
                        isLoading: busy,
                        onPressed: onStart,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Wed, Nov 4 · 8:15 AM" over "Pick up Emma / at 8:30 AM".
class _Headline extends StatelessWidget {
  const _Headline({required this.tracking});

  final RideTracking tracking;

  @override
  Widget build(BuildContext context) {
    final t = tracking;
    final now = DateTime.now();
    final kids = RideFormat.names(t.kidNames, fallback: 'the kids');
    final line1 = 'Pick up $kids';
    final line2 = 'at ${RideFormat.clock(t.pickupAt)}';
    final width = MediaQuery.sizeOf(context).width;
    // Display/L is 44px on a 390pt phone; scale down on narrow screens.
    final size = (width * 44 / 390).clamp(32.0, 44.0);
    final headline = AppTextStyles.displayL.copyWith(
      fontSize: size,
      height: 1,
      letterSpacing: -size * 0.03,
    );
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // The ride's day (the driver may open it the evening before).
            RideFormat.isSameDay(t.pickupAt, now)
                ? 'Today, ${RideFormat.dayDate(t.pickupAt)}'
                : RideFormat.dayDate(t.pickupAt),
            style: RideTextStyles.labelM.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Semantics(
            header: true,
            label: '$line1 $line2',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(line1, maxLines: 1, style: headline),
                ),
                Text(line2, maxLines: 1, style: headline),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 240px dark map card with the "14 min to Lincoln Elementary" pill.
class _MapCard extends StatelessWidget {
  const _MapCard({required this.tracking});

  final RideTracking tracking;

  /// No school run takes longer; beyond it the addresses are wrong (e.g. a
  /// pickup in another country), so the pill is hidden rather than "437 h".
  static const int _maxTripMinutes = 180;

  /// Planned pickup → drop-off minutes, when the ride knows them.
  int? get _tripMinutes {
    final t = tracking;
    int? m;
    if (t.estimatedDropoffAt case final end?) {
      final d = end.difference(t.pickupAt).inMinutes;
      if (d > 0) m = d;
    }
    final miles = t.plannedTripMiles;
    if (m == null && miles != null && miles > 0) {
      // ~20 mph town average.
      m = (miles / 20 * 60).ceil();
    }
    return m != null && m <= _maxTripMinutes ? m : null;
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _tripMinutes;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusMap),
      child: SizedBox(
        height: 240,
        child: ColoredBox(
          color: AppColors.inverse,
          child: Stack(
            children: [
              Positioned.fill(
                child: RideMap(
                  tracking: tracking,
                  padding: const EdgeInsets.only(top: 40),
                  fallback: const _StaticStartMap(),
                ),
              ),
              if (minutes != null)
                Positioned(
                  left: 12,
                  top: 12,
                  right: 12,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.screen,
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusPill,
                        ),
                      ),
                      child: Text(
                        '${RideFormat.minutes(minutes)} to '
                        '${tracking.destination.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RideTextStyles.labelS.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The F20 map artwork (Map/Dark, route, lime school disc), shown when no
/// native map can be created.
class _StaticStartMap extends StatelessWidget {
  const _StaticStartMap();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // Figma card is 358px wide; keep the artwork's x positions relative.
        final sx = box.maxWidth / 358;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: -200,
              top: -300,
              width: 800,
              height: 900,
              child: SvgPicture.asset(
                RideTrackingAssets.mapDark,
                fit: BoxFit.fill,
              ),
            ),
            Positioned(
              left: 40 * sx,
              top: 30,
              child: SvgPicture.asset(
                RideTrackingAssets.startRoute,
                width: 260 * sx,
                height: 180,
                fit: BoxFit.fill,
              ),
            ),
            Positioned(
              left: 262 * sx,
              top: 26,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.lime,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const AppIcon(RideTrackingAssets.schoolIcon, size: 18),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Kid photo, "Emma" and "Home → Lincoln Elementary · Sarah gets alerts
/// automatically".
class _KidsCard extends StatelessWidget {
  const _KidsCard({required this.tracking, required this.parentName});

  final RideTracking tracking;
  final String parentName;

  @override
  Widget build(BuildContext context) {
    final t = tracking;
    final kids = t.kids;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusRow),
      ),
      child: Row(
        children: [
          if (kids.length == 1)
            RideAvatar(
              initials: RideFormat.initials(kids.first.firstName),
              photoUrl: kids.first.photoUrl,
              size: 44,
            )
          else
            RideKidAvatars(
              size: 44,
              kids: [
                for (final k in kids)
                  (RideFormat.initials(k.firstName), k.photoUrl),
              ],
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  RideFormat.names(t.kidNames, fallback: 'Kids'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RideTextStyles.labelL,
                ),
                const SizedBox(height: 1),
                Text(
                  '${t.pickup.label} → ${t.destination.label} · '
                  '$parentName gets alerts automatically',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: RideTextStyles.labelS,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grey pill with an 18px icon and a Label/M caption ("Message Sarah").
class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.semanticLabel,
  });

  final String icon;
  final String label;
  final String? semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                AppIcon(icon, size: 18, color: AppColors.ink),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RideTextStyles.labelM,
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
