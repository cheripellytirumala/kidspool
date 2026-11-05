import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/ride_tracking_assets.dart';
import '../../core/utils/ride_format.dart';
import '../../domain/entities/ride_tracking.dart';
import 'ride_avatar.dart';
import 'ride_styles.dart';

/// F23 "Trip summary": kids, pickup / drop-off times, trip time and (for
/// the requesting parent) who drove.
class TripSummaryCard extends StatelessWidget {
  const TripSummaryCard({
    super.key,
    required this.tracking,
    this.showDriver = true,
  });

  final RideTracking tracking;
  final bool showDriver;

  @override
  Widget build(BuildContext context) {
    final t = tracking;
    final driver = t.driver;
    final minutes = t.tripMinutes;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RideKidAvatars(
                kids: [
                  for (final k in t.kids)
                    (RideFormat.initials(k.firstName), k.photoUrl),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  RideFormat.names(t.kidNames),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RideTextStyles.kidName,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Row(
            icon: RideTrackingAssets.home,
            label:
                'Picked up at ${t.pickup.label.toLowerCase() == 'home' ? 'home' : t.pickup.label}',
            value: t.pickedUpAt == null ? '—' : RideFormat.clock(t.pickedUpAt!),
          ),
          const SizedBox(height: 12),
          _Row(
            icon: RideTrackingAssets.school,
            label: 'Dropped off at ${t.destination.label}',
            value: t.completedAt == null
                ? '—'
                : RideFormat.clock(t.completedAt!),
          ),
          const SizedBox(height: 12),
          _Row(
            icon: RideTrackingAssets.clock,
            label: 'Trip time',
            value: minutes == null ? '—' : RideFormat.minutes(minutes),
          ),
          if (showDriver && driver != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                RideAvatar(initials: driver.initials, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Driven by ${driver.shortName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RideTextStyles.labelL,
                      ),
                      if (driver.vehicleLine case final car?)
                        Text(
                          car,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RideTextStyles.body14,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.screen,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: AppIcon(icon, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: RideTextStyles.rowLabel)),
        const SizedBox(width: 12),
        Text(value, style: RideTextStyles.rowValue),
      ],
    );
  }
}
