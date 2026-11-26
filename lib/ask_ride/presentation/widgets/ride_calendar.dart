import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../core/constants/ask_ride_assets.dart';
import '../../core/utils/ride_date_format.dart';
import 'ask_ride_text_styles.dart';

/// One-week strip from the "Select day?" / "Which days?" sheets: seven days
/// from [start], never before [firstDate] (today), so no past day is shown.
/// The arrows move a week at a time; back stops at [firstDate].
class RideCalendar extends StatelessWidget {
  const RideCalendar({
    super.key,
    required this.start,
    required this.firstDate,
    required this.isSelected,
    required this.onDayTap,
    required this.onWeekChanged,
  });

  /// First day of the week on screen.
  final DateTime start;
  final DateTime firstDate;
  final bool Function(DateTime day) isSelected;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTime> onWeekChanged;

  static const int days = 7;

  /// The week (counted from [firstDate]) that holds [day]; [firstDate]
  /// itself for a day before it.
  static DateTime weekOf(DateTime day, DateTime firstDate) {
    final first = RideDateFormat.dateOnly(firstDate);
    final d = RideDateFormat.dateOnly(day);
    if (!d.isAfter(first)) return first;
    final weeks = d.difference(first).inDays ~/ days;
    return DateTime(first.year, first.month, first.day + weeks * days);
  }

  @override
  Widget build(BuildContext context) {
    final first = RideDateFormat.dateOnly(firstDate);
    final from = RideDateFormat.dateOnly(start).isBefore(first)
        ? first
        : RideDateFormat.dateOnly(start);
    final week = [
      for (var i = 0; i < days; i++)
        DateTime(from.year, from.month, from.day + i),
    ];
    final canGoBack = from.isAfter(first);

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
                  tooltip: 'Previous week',
                  // The exported asset is the disabled grey; tint when active.
                  color: canGoBack ? AppColors.ink : null,
                  onTap: canGoBack
                      ? () {
                          final back = DateTime(
                            from.year,
                            from.month,
                            from.day - days,
                          );
                          onWeekChanged(back.isBefore(first) ? first : back);
                        }
                      : null,
                ),
                Expanded(
                  child: Text(
                    RideDateFormat.range(week.first, week.last),
                    textAlign: TextAlign.center,
                    style: AskRideTextStyles.month,
                  ),
                ),
                _MonthArrow(
                  asset: AskRideAssets.monthNext,
                  tooltip: 'Next week',
                  onTap: () => onWeekChanged(
                    DateTime(from.year, from.month, from.day + days),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < week.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: _DayCell(
                    day: week[i],
                    isToday: RideDateFormat.isSameDay(week[i], first),
                    selected: isSelected(week[i]),
                    onTap: () => onDayTap(week[i]),
                  ),
                ),
              ],
            ],
          ),
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

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textOnDark : AppColors.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      label: isToday
          ? 'Today, ${RideDateFormat.long(day)}'
          : RideDateFormat.long(day),
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.ink : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  RideDateFormat.weekdayShort(day.weekday).substring(0, 1),
                  style: AskRideTextStyles.weekdayLetter.copyWith(
                    color: selected ? AppColors.textOnDark : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${day.day}',
                  style: AskRideTextStyles.labelL.copyWith(color: color),
                ),
                const SizedBox(height: 2),
                // Dot under today.
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isToday ? color : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
