import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../core/constants/ask_ride_assets.dart';
import '../../domain/entities/ride_time.dart';
import 'ask_ride_common.dart';
import 'ask_ride_text_styles.dart';

enum RideTimeFieldStyle {
  /// "Field · Time": surface row, clock in a white disc ("Pick up at").
  field,

  /// "Field · Return time": white row, bare clock, pencil on the right.
  inline,
}

/// Time picked from a wheel (hour · minute in 5-minute steps · AM/PM).
/// Tapping the row opens the wheel in a bottom sheet; nothing is typed.
class RideTimeField extends StatelessWidget {
  const RideTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.style = RideTimeFieldStyle.field,
  });

  final String label;
  final RideTime? value;
  final ValueChanged<RideTime?> onChanged;
  final RideTimeFieldStyle style;

  /// Minutes on the wheel move in these steps.
  static const int minuteStep = 5;

  Future<void> _pick(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final fallback = style == RideTimeFieldStyle.inline
        ? const RideTime(15, 30)
        : const RideTime(8, 0);
    final picked = await showRideTimeWheel(
      context,
      title: label,
      initial: value ?? fallback,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final inline = style == RideTimeFieldStyle.inline;
    final text = value?.format();
    return Semantics(
      button: true,
      label: '$label, ${text ?? 'not set'}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _pick(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: inline ? AppColors.screen : AppColors.surface,
            borderRadius: BorderRadius.circular(inline ? 18 : kFieldRowRadius),
          ),
          child: Row(
            children: [
              if (inline)
                SvgPicture.asset(
                  AskRideAssets.clockSmall,
                  width: 18,
                  height: 18,
                )
              else
                IconDisc(
                  child: SvgPicture.asset(
                    AskRideAssets.clock,
                    width: 16,
                    height: 16,
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: AskRideTextStyles.fieldCaption),
                    if (!inline) const SizedBox(height: 1),
                    Text(
                      text ?? 'Choose a time',
                      style: AskRideTextStyles.labelL.copyWith(
                        color: text == null ? AppColors.textSecondary : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (inline)
                SvgPicture.asset(AskRideAssets.pencil, width: 16, height: 16)
              else
                const Icon(
                  Icons.expand_more_rounded,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet with an iOS-style time wheel. Returns the time on "Done",
/// `null` when dismissed.
Future<RideTime?> showRideTimeWheel(
  BuildContext context, {
  required String title,
  required RideTime initial,
}) {
  return showModalBottomSheet<RideTime>(
    context: context,
    // Sized by its content (the default cap is ~56% of the screen, which
    // clips the wheel on small phones); scrolls if it still doesn't fit.
    isScrollControlled: true,
    backgroundColor: AppColors.screen,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => _TimeWheelSheet(title: title, initial: initial),
  );
}

class _TimeWheelSheet extends StatefulWidget {
  const _TimeWheelSheet({required this.title, required this.initial});

  final String title;
  final RideTime initial;

  @override
  State<_TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<_TimeWheelSheet> {
  static const _step = RideTimeField.minuteStep;

  // The wheel only shows multiples of the step, so start on one.
  late RideTime _time = RideTime(
    widget.initial.hour,
    widget.initial.minute - widget.initial.minute % _step,
  );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: AppTextStyles.headingH3),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: AppTextStyles.bodyL.copyWith(
                      fontSize: 22,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  minuteInterval: _step,
                  use24hFormat: false,
                  initialDateTime: DateTime(
                    now.year,
                    now.month,
                    now.day,
                    _time.hour,
                    _time.minute,
                  ),
                  onDateTimeChanged: (d) =>
                      setState(() => _time = RideTime(d.hour, d.minute)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Done',
              onPressed: () => Navigator.of(context).pop(_time),
            ),
          ],
        ),
      ),
    );
  }
}
