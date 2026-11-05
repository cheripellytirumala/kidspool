import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/ride_tracking_assets.dart';
import '../../core/utils/ride_format.dart';
import '../../domain/entities/ride_alert.dart';
import 'ride_styles.dart';

/// S19 "Alert · Ride started" / S20 "Alert · Arrived at school": the lime
/// notification card, shown in-app by [RideAlertsHost].
class RideAlertCard extends StatelessWidget {
  const RideAlertCard({
    super.key,
    required this.alert,
    required this.onOpen,
    this.onClose,
  });

  final RideAlert alert;

  /// "Track live" / "See ride summary" (also a tap on the card); null when
  /// the notification doesn't name a ride.
  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  bool get _started => alert.kind == RideAlertKind.started;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: AppColors.lime,
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.ink,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: AppIcon(
                        _started
                            ? RideTrackingAssets.alertCar
                            : RideTrackingAssets.alertCheck,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KIDPOOL · ${RideFormat.ago(alert.createdAt)}',
                            style: RideTextStyles.alertMeta,
                          ),
                          Text(
                            alert.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.headingH3,
                          ),
                        ],
                      ),
                    ),
                    if (onClose != null)
                      // No IconButton/Tooltip: the card can sit above the
                      // Navigator's Overlay (MaterialApp.builder).
                      Semantics(
                        button: true,
                        label: 'Dismiss',
                        excludeSemantics: true,
                        child: InkResponse(
                          onTap: onClose,
                          radius: 22,
                          child: const SizedBox.square(
                            dimension: 44,
                            child: Icon(
                              Icons.close_rounded,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (alert.body case final body?) ...[
                  const SizedBox(height: 12),
                  Text(
                    body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyL,
                  ),
                ],
                if (onOpen != null) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: AppColors.ink,
                    shape: const StadiumBorder(),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: onOpen,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 18, 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppIcon(
                              RideTrackingAssets.alertMap,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _started ? 'Track live' : 'See ride summary',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: RideTextStyles.alertButton,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Max width of the banner on large screens.
const double kRideAlertMaxWidth = 430 - 2 * 16;

/// Horizontal inset of the banner (Figma: 16).
const double kRideAlertInset = AppDimens.screenPadding - 4;
