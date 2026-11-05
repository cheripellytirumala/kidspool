import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../domain/entities/ride_tracking.dart';
import 'ride_styles.dart';

/// Call / message / SOS helpers. Message opens the ride chat; the app has
/// no `url_launcher`, so Call shows the number (with Copy) instead of dialing.
abstract final class RideContact {
  static void call(
    BuildContext context, {
    required String name,
    String? phone,
  }) {
    if (phone == null || phone.trim().isEmpty) {
      showAppSnack(context, 'We don’t have a phone number for $name.');
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Call $name at $phone'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          action: SnackBarAction(
            label: 'Copy',
            textColor: AppColors.lime,
            onPressed: () => Clipboard.setData(ClipboardData(text: phone)),
          ),
        ),
      );
  }

  /// Opens this ride's chat (F19) with the other grown-up.
  static void message(BuildContext context, RideTracking tracking) {
    final other = tracking.isDriver ? tracking.parent : tracking.driver;
    final driverId = tracking.driver?.id;
    if (driverId == null || driverId.isEmpty) {
      showAppSnack(context, 'This ride has no Ride Partner to message yet.');
      return;
    }
    Navigator.of(context).pushNamed(
      AppRoutes.rideChat,
      arguments: RideChatArgs(
        requestId: tracking.requestId,
        driverId: driverId,
        iAmDriver: tracking.isDriver,
        otherName: other?.firstName,
        otherInitials: other?.initials,
      ),
    );
  }

  /// Emergency dialog. Returns true when the user chose to alert the other
  /// grown-up on the ride (`trigger_sos`).
  static Future<bool> confirmSos(
    BuildContext context, {
    required String otherName,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.screen,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Emergency?', style: AppTextStyles.headingH3),
              const SizedBox(height: 8),
              Text(
                'If anyone is in danger, call 911 now from your phone.',
                style: AppTextStyles.bodyL,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: RideColors.sos,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  '911',
                  style: RideTextStyles.numberL.copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You can also alert $otherName and KidPool about this ride.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Send SOS alert',
                variant: AppButtonVariant.dark,
                onPressed: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Close',
                variant: AppButtonVariant.light,
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }
}
