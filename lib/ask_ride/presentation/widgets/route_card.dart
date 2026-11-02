import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../core/constants/ask_ride_assets.dart';
import '../../domain/entities/saved_place.dart';
import 'ask_ride_common.dart';
import 'ask_ride_text_styles.dart';

/// "Route" block: pick-up row, dashed connector with "Swap", drop-off row.
class RouteCard extends StatelessWidget {
  const RouteCard({
    super.key,
    required this.pickup,
    required this.dropOff,
    required this.pickupSubtitle,
    required this.onPickupTap,
    required this.onDropOffTap,
    required this.onSwap,
  });

  final SavedPlace? pickup;
  final SavedPlace? dropOff;

  /// e.g. `24 Maple St · pick-up 8:30 AM`.
  final String pickupSubtitle;
  final VoidCallback onPickupTap;
  final VoidCallback onDropOffTap;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final drop = dropOff;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          RouteEndRow(
            caption: 'PICK UP FROM',
            place: pickup,
            subtitle: pickupSubtitle,
            onTap: onPickupTap,
          ),
          SizedBox(
            height: 36,
            child: Padding(
              padding: const EdgeInsets.only(left: 30, right: 8),
              child: Row(
                children: [
                  // The Figma line is a horizontal 24×2 dash rotated 90°.
                  RotatedBox(
                    quarterTurns: 1,
                    child: SvgPicture.asset(
                      AskRideAssets.dashedLine,
                      width: 24,
                      height: 2,
                    ),
                  ),
                  const Spacer(),
                  _SwapButton(onTap: onSwap),
                ],
              ),
            ),
          ),
          RouteEndRow(
            caption: 'DROP OFF AT',
            place: drop,
            subtitle: drop == null
                ? ''
                : [drop.address, ?drop.detail].join(' · '),
            onTap: onDropOffTap,
          ),
        ],
      ),
    );
  }
}

/// White row inside the route block ("End · Pickup" / "End · Drop-off").
class RouteEndRow extends StatelessWidget {
  const RouteEndRow({
    super.key,
    required this.caption,
    required this.place,
    required this.subtitle,
    required this.onTap,
  });

  final String caption;
  final SavedPlace? place;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final place = this.place;
    return Material(
      color: AppColors.screen,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Row(
            children: [
              if (place != null)
                PlaceIcon(kind: place.kind)
              else
                const IconDisc(
                  size: 40,
                  color: AppColors.surface,
                  child: SizedBox.shrink(),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(caption, style: AskRideTextStyles.fieldCaption),
                    const SizedBox(height: 1),
                    Text(
                      place?.name ?? 'Choose a place',
                      style: AskRideTextStyles.labelL.copyWith(
                        color: place == null ? AppColors.textSecondary : null,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(subtitle, style: AskRideTextStyles.fieldCaption),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SvgPicture.asset(
                AskRideAssets.chevronDown,
                width: 18,
                height: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Swap pick-up and drop-off',
      excludeSemantics: true,
      child: Material(
        color: AppColors.screen,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(AskRideAssets.repeat, width: 16, height: 16),
                const SizedBox(width: 6),
                Text('Swap', style: AskRideTextStyles.swap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
