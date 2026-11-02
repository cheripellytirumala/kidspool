import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../core/constants/ask_ride_assets.dart';
import '../../domain/entities/ride_time.dart';
import '../../domain/entities/saved_place.dart';
import 'ask_ride_common.dart';
import 'ask_ride_text_styles.dart';
import 'ride_time_field.dart';

/// Lime-tint "Return details" block: drop-off → pick-up and the return
/// pick-up time the parent types in.
class ReturnTripDetails extends StatelessWidget {
  const ReturnTripDetails({
    super.key,
    required this.from,
    required this.to,
    required this.time,
    required this.onTimeChanged,
  });

  final SavedPlace? from;
  final SavedPlace? to;
  final RideTime? time;
  final ValueChanged<RideTime?> onTimeChanged;

  @override
  Widget build(BuildContext context) {
    final from = this.from;
    final to = this.to;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.limeTint,
        borderRadius: BorderRadius.circular(kFieldRowRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (from != null) ...[
                PlaceGlyph(kind: from.kind),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    from.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AskRideTextStyles.labelM,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // The Figma chevron points left and is rotated 180°.
              RotatedBox(
                quarterTurns: 2,
                child: SvgPicture.asset(
                  AskRideAssets.chevronSmall,
                  width: 14,
                  height: 14,
                ),
              ),
              if (to != null) ...[
                const SizedBox(width: 8),
                PlaceGlyph(kind: to.kind),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    to.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AskRideTextStyles.labelM,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          RideTimeField(
            label: 'Return pickup time · type it in',
            value: time,
            onChanged: onTimeChanged,
            style: RideTimeFieldStyle.inline,
          ),
        ],
      ),
    );
  }
}
