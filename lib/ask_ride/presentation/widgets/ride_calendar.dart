import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../core/constants/ask_ride_assets.dart';
import '../../core/utils/ride_date_format.dart';
import 'ask_ride_text_styles.dart';

/// Month grid from the "Select day?" / "Which days?" sheets. Weeks start on
/// Sunday; days before [firstDate] are dimmed and not tappable.
class RideCalendar extends StatelessWidget {
  const RideCalendar({
    super.key,
    required this.month,
    required this.firstDate,
    required this.isSelected,
    required this.onDayTap,
    required this.onMonthChanged,
    this.isWeekBanded,
  });

  /// Any day in the month to show.
  final DateTime month;
  final DateTime firstDate;
  final bool Function(DateTime day) isSelected;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTime> onMonthChanged;

  /// Grey band behind a whole week (repeating weeks in "Which days?").
  /// Receives the Sunday that starts the week.
  final bool Function(DateTime weekStart)? isWeekBanded;

  static const List<String> _letters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday % 7; // Sunday → 0
    final rows = ((leading + daysInMonth) / 7).ceil();
    final canGoBack = first.isAfter(DateTime(firstDate.year, firstDate.month));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                _MonthArrow(
                  asset: AskRideAssets.monthPrev,
                  tooltip: 'Previous month',
                  // The exported asset is the disabled grey; tint when active.
                  color: canGoBack ? AppColors.ink : null,
                  onTap: canGoBack
                      ? () => onMonthChanged(
                          DateTime(month.year, month.month - 1),
                        )
                      : null,
                ),
                Expanded(
                  child: Text(
                    RideDateFormat.monthYear(first),
                    textAlign: TextAlign.center,
                    style: AskRideTextStyles.month,
                  ),
                ),
                _MonthArrow(
                  asset: AskRideAssets.monthNext,
                  tooltip: 'Next month',
                  onTap: () =>
                      onMonthChanged(DateTime(month.year, month.month + 1)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: SizedBox(
                    height: 24,
                    child: Center(
                      child: Text(
                        _letters[i],
                        style: AskRideTextStyles.weekdayLetter,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          for (var r = 0; r < rows; r++) ...[
            const SizedBox(height: 6),
            _WeekRow(
              banded:
                  isWeekBanded?.call(
                    DateTime(month.year, month.month, 1 - leading + r * 7),
                  ) ??
                  false,
              days: [
                for (var c = 0; c < 7; c++)
                  () {
                    final day = r * 7 + c - leading + 1;
                    return day < 1 || day > daysInMonth
                        ? null
                        : DateTime(month.year, month.month, day);
                  }(),
              ],
              firstDate: RideDateFormat.dateOnly(firstDate),
              isSelected: isSelected,
              onDayTap: onDayTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({
    required this.asset,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final String asset;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: tooltip,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: SvgPicture.asset(
          asset,
          width: 20,
          height: 20,
          colorFilter: color == null
              ? null
              : ColorFilter.mode(color!, BlendMode.srcIn),
        ),
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.banded,
    required this.days,
    required this.firstDate,
    required this.isSelected,
    required this.onDayTap,
  });

  final bool banded;
  final List<DateTime?> days;
  final DateTime firstDate;
  final bool Function(DateTime day) isSelected;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: banded ? AppColors.surfaceStrong : Colors.transparent,
      child: Row(
        children: [
          for (var i = 0; i < days.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(child: _dayCell(days[i])),
          ],
        ],
      ),
    );
  }

  Widget _dayCell(DateTime? day) {
    if (day == null) return const SizedBox(height: 42);
    final disabled = day.isBefore(firstDate);
    final selected = !disabled && isSelected(day);
    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      label: RideDateFormat.long(day),
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.ink : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: disabled ? null : () => onDayTap(day),
          customBorder: const StadiumBorder(),
          child: SizedBox(
            height: 42,
            child: Center(
              child: Opacity(
                opacity: disabled ? 0.4 : 1,
                child: Text(
                  '${day.day}',
                  style: AskRideTextStyles.labelL.copyWith(
                    color: selected
                        ? AppColors.textOnDark
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
