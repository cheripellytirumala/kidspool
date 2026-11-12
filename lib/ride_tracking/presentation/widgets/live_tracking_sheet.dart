import 'package:flutter/material.dart';

import '../../core/constants/ride_tracking_api_constants.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../core/constants/ride_tracking_assets.dart';
import '../../core/utils/ride_format.dart';
import '../../domain/entities/ride_tracking.dart';
import '../providers/live_tracking_provider.dart';
import 'ride_avatar.dart';
import 'ride_buttons.dart';
import 'ride_styles.dart';

/// F22 bottom "Sheet": ETA + route, stats card, the other grown-up, and the
/// Ride Partner's next step.
class LiveTrackingSheet extends StatelessWidget {
  const LiveTrackingSheet({
    super.key,
    required this.tracking,
    required this.driverAction,
    required this.busyAction,
    required this.onDriverAction,
    required this.onMessage,
    required this.onCall,
    this.canDropOff = true,
    this.metersToDropoff,
  });

  /// Within 100 m of the drop-off (no distance hint then).
  final bool canDropOff;
  final double? metersToDropoff;

  final RideTracking tracking;
  final DriverRideAction? driverAction;
  final DriverRideAction? busyAction;
  final VoidCallback onDriverAction;
  final VoidCallback onMessage;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final action = driverAction;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: RideShadows.sheet,
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottom > 16 ? bottom + 8 : 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.surfaceStrong,
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Eta(tracking: tracking)),
                const SizedBox(width: 16),
                Expanded(child: _Route(tracking: tracking)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Stats(tracking: tracking),
          const SizedBox(height: 16),
          _PersonRow(tracking: tracking, onMessage: onMessage, onCall: onCall),
          if (action != null) ...[
            const SizedBox(height: 16),
            if (action == DriverRideAction.complete && !canDropOff) ...[
              Text(
                _dropoffHint(metersToDropoff),
                textAlign: TextAlign.center,
                style: RideTextStyles.labelS,
              ),
              const SizedBox(height: 8),
            ],
            AppButton(
              label: _actionLabel(action, tracking),
              isLoading: busyAction != null,
              onPressed: onDriverAction,
            ),
          ],
        ],
      ),
    );
  }

  /// "Drops off automatically within 100 m · 350 m to go".
  static String _dropoffHint(double? meters) {
    final radius = RideTrackingApiConstants.dropoffRadiusMeters.round();
    final left = meters == null
        ? ''
        : meters >= 1000
        ? ' · ${(meters / 1000).toStringAsFixed(1)} km to go'
        : ' · ${meters.round()} m to go';
    return 'Drops off automatically within $radius m$left';
  }

  static String _actionLabel(DriverRideAction action, RideTracking t) =>
      switch (action) {
        DriverRideAction.start => 'Start ride',
        DriverRideAction.pickedUp =>
          'Picked up ${RideFormat.names(t.kidNames, fallback: 'the kids')}',
        DriverRideAction.complete =>
          t.hasCustomDropoff ? 'Dropped off' : 'Dropped off at school',
      };
}

class _Eta extends StatelessWidget {
  const _Eta({required this.tracking});

  final RideTracking tracking;

  @override
  Widget build(BuildContext context) {
    final t = tracking;
    final (label, value) = switch (t.status) {
      RideTrackingStatus.inProgress => (
        t.pickedUp ? 'Arriving in' : 'Pickup in',
        switch (t.minutesToGo()) {
          final m? => RideFormat.minutes(m),
          null => '—',
        },
      ),
      _ => ('Pickup at', RideFormat.clock(t.pickupAt)),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: RideTextStyles.labelS),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, maxLines: 1, style: RideTextStyles.numberXL),
        ),
      ],
    );
  }
}

class _Route extends StatelessWidget {
  const _Route({required this.tracking});

  final RideTracking tracking;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Route', style: RideTextStyles.labelS),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Column(
                children: [
                  const _Dot(fill: AppColors.ink),
                  const SizedBox(height: 4),
                  Container(
                    width: 2,
                    height: 28,
                    color: AppColors.surfaceStrong,
                  ),
                  const SizedBox(height: 4),
                  const _Dot(fill: AppColors.lime, ring: AppColors.ink),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stop(tracking.pickup.label),
                  const SizedBox(height: 14),
                  _stop(tracking.destination.label),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stop(String label) => Text(
    label,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: RideTextStyles.labelM,
  );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.fill, this.ring});

  final Color fill;
  final Color? ring;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: fill,
      shape: BoxShape.circle,
      border: ring == null ? null : Border.all(color: ring!, width: 1.5),
    ),
  );
}

class _Stats extends StatelessWidget {
  const _Stats({required this.tracking});

  final RideTracking tracking;

  @override
  Widget build(BuildContext context) {
    final t = tracking;
    final first = switch (t) {
      RideTracking(pickedUpAt: final at?) => (
        RideFormat.shortClock(at),
        'Picked up',
      ),
      RideTracking(startedAt: final at?) => (
        RideFormat.shortClock(at),
        'Started',
      ),
      _ => (RideFormat.shortClock(t.pickupAt), 'Pickup'),
    };
    final meters = t.metersToGo;
    final miles = meters != null
        ? meters / RideFormat.metersPerMile
        : t.plannedTripMiles;
    final second = (miles == null ? '—' : RideFormat.miles(miles), 'To go');
    final third = t.sosOpen
        ? ('SOS', 'Alert open')
        : ('Safe', t.inSchoolZone ? 'Class zone' : 'On route');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.inverse,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(value: first.$1, label: first.$2),
          ),
          const _Divider(),
          Expanded(
            child: _Stat(value: second.$1, label: second.$2),
          ),
          const _Divider(),
          Expanded(
            child: _Stat(value: third.$1, label: third.$2, alert: t.sosOpen),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: RideColors.borderDark);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.alert = false});

  final String value;
  final String label;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: RideTextStyles.numberL.copyWith(
                  color: alert ? RideColors.sos : null,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RideTextStyles.bodyS.copyWith(
                color: AppColors.textOnDarkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.tracking,
    required this.onMessage,
    required this.onCall,
  });

  final RideTracking tracking;
  final VoidCallback onMessage;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final t = tracking;
    // The parent sees their Ride Partner; the Ride Partner sees the parent.
    final person = t.isDriver ? t.parent : t.driver;
    final name = person?.name ?? (t.isDriver ? 'Parent' : 'Ride Partner');
    final subtitle = t.isDriver
        ? 'Parent of ${RideFormat.names(t.kidNames, fallback: 'the kids')}'
        : person?.vehicleLine ?? 'Ride Partner';
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          RideAvatar(
            initials: person?.initials ?? RideFormat.initials(name),
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RideTextStyles.labelL,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RideTextStyles.bodyS,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          RideIconButton(
            icon: RideTrackingAssets.chat,
            semanticLabel: 'Message ${person?.firstName ?? name}',
            onPressed: onMessage,
          ),
          const SizedBox(width: 12),
          RideIconButton(
            icon: RideTrackingAssets.phone,
            semanticLabel: 'Call ${person?.firstName ?? name}',
            background: AppColors.ink,
            onPressed: onCall,
          ),
        ],
      ),
    );
  }
}
