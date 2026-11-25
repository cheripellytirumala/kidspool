import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../core/constants/ask_ride_assets.dart';
import '../../core/utils/ride_date_format.dart';
import 'ask_ride_text_styles.dart';

/// Two-week grid for the "Select day?" / "Which days?" sheets: the week
/// containing [month] and the one after (current and next week by
/// default). Weeks start on Sunday; days before [firstDate] are dimmed and
/// not tappable. The arrows move two weeks at a time.
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

  /// Any day in the first week to show.
  final DateTime month;
  final DateTime firstDate;
  final bool Function(DateTime day) isSelected;
  final ValueChanged<DateTime> onDayTap;

  /// Called with a day in the newly shown first week.
  final ValueChanged<DateTime> onMonthChanged;

  /// Grey band behind a whole week (repeating weeks in "Which days?").
  /// Receives the Sunday that starts the week.
  final bool Function(DateTime weekStart)? isWeekBanded;

  /// Weeks shown at once.
  static const int weeks = 2;

  static const List<String> _letters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  /// The Sunday starting [day]'s week.
  static DateTime weekStart(DateTime day) =>
      DateTime(day.year, day.month, day.day - day.weekday % 7);

  /// The days on screen when the first week contains [day].
  static List<DateTime> shownDays(DateTime day) {
    final start = weekStart(day);
    return [
      for (var i = 0; i < weeks * 7; i++)
        DateTime(start.year, start.month, start.day + i),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final start = weekStart(month);
    final days = shownDays(month);
    final last = days.last;
    final canGoBack = start.isAfter(weekStart(firstDate));
    final title = start.month == last.month
        ? RideDateFormat.monthYear(start)
        : start.year == last.year
        ? '${RideDateFormat.monthYear(start).split(' ').first} – '
              '${RideDateFormat.monthYear(last)}'
        : '${RideDateFormat.monthYear(start)} – '
              '${RideDateFormat.monthYear(last)}';

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
                  tooltip: 'Previous weeks',
                  // The exported asset is the disabled grey; tint when active.
                  color: canGoBack ? AppColors.ink : null,
                  onTap: canGoBack
                      ? () => onMonthChanged(
                          DateTime(
                            start.year,
                            start.month,
                            start.day - weeks * 7,
                          ),
                        )
                      : null,
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AskRideTextStyles.month,
                  ),
                ),
                _MonthArrow(
                  asset: AskRideAssets.monthNext,
                  tooltip: 'Next weeks',
                  onTap: () => onMonthChanged(
                    DateTime(start.year, start.month, start.day + weeks * 7),
                  ),
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
          for (var r = 0; r < weeks; r++) ...[
            const SizedBox(height: 6),
            _WeekRow(
              banded: isWeekBanded?.call(days[r * 7]) ?? false,
              days: days.sublist(r * 7, r * 7 + 7),
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
