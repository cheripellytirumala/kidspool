import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../core/utils/ride_format.dart';
import '../../domain/entities/ride_tracking.dart';
import 'ride_styles.dart';

/// Requesting parent: the 4-digit code to give the Ride Partner when the
/// kids get in the car (QA #7).
class PickupPinCard extends StatelessWidget {
  const PickupPinCard({super.key, required this.pin, this.driverName});

  final String pin;
  final String? driverName;

  @override
  Widget build(BuildContext context) {
    final who = driverName ?? 'your Ride Partner';
    return Semantics(
      label:
          'Pick-up PIN ${pin.split('').join(' ')}. Give it to $who '
          'when your members get in the car.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.limeTint,
          borderRadius: BorderRadius.circular(AppDimens.radiusRow),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pick-up PIN', style: RideTextStyles.labelS),
                  const SizedBox(height: 2),
                  Text(
                    'Give it to $who when your members get in the car. '
                    'Don’t share it before.',
                    style: RideTextStyles.bodyS,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              pin,
              style: RideTextStyles.numberXL.copyWith(letterSpacing: 4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Requesting parent: what to look for at the kerb (QA #6, #9, #14).
class DriverCarCard extends StatelessWidget {
  const DriverCarCard({super.key, required this.driver});

  final RidePerson driver;

  static bool hasInfo(RidePerson? d) =>
      d != null &&
      (d.carDescription != null ||
          (d.plate?.trim().isNotEmpty ?? false) ||
          d.seatsLine != null);

  @override
  Widget build(BuildContext context) {
    final d = driver;
    final plate = d.plate?.trim();
    final details = [
      d.carDescription,
      if (d.carSeats != null) '${d.carSeats}-seater',
      d.seatsLine,
      if (d.genderLabel case final g?) 'Driver: $g',
    ].whereType<String>().join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusRow),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Look for', style: RideTextStyles.labelS),
                const SizedBox(height: 2),
                Text(
                  details.isEmpty ? 'Car details not added yet' : details,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: RideTextStyles.bodyS,
                ),
              ],
            ),
          ),
          if (plate != null && plate.isNotEmpty) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.screen,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.ink, width: 1.5),
              ),
              child: Text(
                plate.toUpperCase(),
                semanticsLabel: 'Number plate $plate',
                style: RideTextStyles.labelL.copyWith(letterSpacing: 1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ride still in progress an hour past the drop-off (QA #12).
class RideOverdueBanner extends StatelessWidget {
  const RideOverdueBanner({super.key, required this.tracking});

  final RideTracking tracking;

  @override
  Widget build(BuildContext context) {
    final end = tracking.autoEndAt;
    final text = tracking.isDriver
        ? 'This ride is running over an hour late. Tap Dropped off when '
              'you arrive'
        : 'This ride is running over an hour late. Call your Ride Partner '
              'if you’re worried';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: RideColors.sos.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusRow),
      ),
      child: Text(
        end == null
            ? '$text.'
            : '$text — it closes by itself at ${RideFormat.clock(end)}.',
        style: RideTextStyles.bodyS.copyWith(color: AppColors.ink),
      ),
    );
  }
}

/// Small text button under the sheet: "Cancel ride".
class CancelRideLink extends StatelessWidget {
  const CancelRideLink({super.key, required this.onPressed, this.busy = false});

  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: busy ? null : onPressed,
      child: Text(
        busy ? 'Cancelling…' : 'Cancel ride',
        style: RideTextStyles.labelM.copyWith(color: RideColors.sos),
      ),
    );
  }
}

abstract final class RideSafetyDialogs {
  static Widget _shell(List<Widget> children) => Dialog(
    backgroundColor: AppColors.screen,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );

  /// Ride Partner: asks for the parent's 4-digit PIN before "Picked up".
  /// Returns the PIN, `''` to go on without one (only when [allowSkip]:
  /// the parent's app is too old to show it), or null when dismissed.
  static Future<String?> askPickupPin(
    BuildContext context, {
    required String parentName,
    required bool allowSkip,
  }) => showDialog<String>(
    context: context,
    builder: (context) =>
        _PinDialog(parentName: parentName, allowSkip: allowSkip),
  );

  /// Either side: confirm cancelling a started ride. Returns the reason
  /// (may be empty) or null when kept.
  static Future<String?> confirmCancel(
    BuildContext context, {
    required bool isDriver,
    required String otherName,
  }) {
    final reasons = isDriver
        ? const ['Can’t make it to the pick-up', 'Car trouble', 'Other']
        : const [
            'Ride Partner isn’t coming',
            'Plans changed',
            'Found another ride',
            'Other',
          ];
    return showDialog<String>(
      context: context,
      builder: (context) {
        var picked = reasons.first;
        return StatefulBuilder(
          builder: (context, setState) => _shell([
            Text('Cancel this ride?', style: AppTextStyles.headingH3),
            const SizedBox(height: 8),
            Text(
              'The members haven’t been picked up yet. $otherName will be told '
              'right away.',
              style: AppTextStyles.bodyL,
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: picked,
              onChanged: (v) => setState(() => picked = v ?? picked),
              child: Column(
                children: [
                  for (final r in reasons)
                    RadioListTile<String>(
                      value: r,
                      contentPadding: EdgeInsets.zero,
                      title: Text(r, style: AppTextStyles.bodyL),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Cancel ride',
              variant: AppButtonVariant.dark,
              onPressed: () =>
                  Navigator.of(context).pop(picked == 'Other' ? '' : picked),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Keep ride',
              variant: AppButtonVariant.light,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ]),
        );
      },
    );
  }
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.parentName, required this.allowSkip});

  final String parentName;
  final bool allowSkip;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RideSafetyDialogs._shell([
      Text('Pick-up PIN', style: AppTextStyles.headingH3),
      const SizedBox(height: 8),
      Text(
        'Ask ${widget.parentName} for the 4-digit PIN in their KidsPool app.',
        style: AppTextStyles.bodyL,
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 4,
        style: RideTextStyles.numberXL.copyWith(letterSpacing: 12),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(counterText: '', hintText: '• • • •'),
        onChanged: (_) => setState(() {}),
        onSubmitted: (v) {
          if (v.length == 4) Navigator.of(context).pop(v);
        },
      ),
      const SizedBox(height: 16),
      AppButton(
        label: 'Confirm pick-up',
        onPressed: _controller.text.length == 4
            ? () => Navigator.of(context).pop(_controller.text)
            : null,
      ),
      if (widget.allowSkip) ...[
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => Navigator.of(context).pop(''),
          child: Text(
            'Parent can’t see a PIN? Continue without',
            style: RideTextStyles.labelM.copyWith(color: RideColors.muted),
          ),
        ),
      ],
    ]);
  }
}
