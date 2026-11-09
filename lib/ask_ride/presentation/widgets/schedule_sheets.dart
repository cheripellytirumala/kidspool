import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../core/constants/ask_ride_assets.dart';
import '../../core/utils/ride_date_format.dart';
import '../../domain/entities/ride_schedule.dart';
import '../../domain/entities/ride_time.dart';
import 'ask_ride_common.dart';
import 'ask_ride_sheet.dart';
import 'ask_ride_text_styles.dart';
import 'ride_calendar.dart';
import 'ride_time_field.dart';

typedef OnceSelection = ({DateTime date, RideTime time});
typedef CustomSelection = ({Set<DateTime> dates, RideTime time});

DateTime _today() => RideDateFormat.dateOnly(DateTime.now());

/// "Select day?" — one date plus the pick-up time.
class SelectDaySheet extends StatefulWidget {
  const SelectDaySheet({super.key, this.initial, this.initialTime});

  final OnceSchedule? initial;
  final RideTime? initialTime;

  @override
  State<SelectDaySheet> createState() => _SelectDaySheetState();
}

class _SelectDaySheetState extends State<SelectDaySheet> {
  late DateTime? _date = widget.initial?.date;
  late DateTime _month = _date ?? _today();
  late RideTime? _time = widget.initialTime;

  bool get _canFinish => _date != null && _time != null;

  @override
  Widget build(BuildContext context) {
    final date = _date;
    return AskRideSheet(
      title: 'Select day?',
      footer: _DoneButton(
        onPressed: _canFinish
            ? () => Navigator.of(
                context,
              ).pop<OnceSelection>((date: date!, time: _time!))
            : null,
      ),
      children: [
        RideCalendar(
          month: _month,
          firstDate: _today(),
          isSelected: (d) => date != null && RideDateFormat.isSameDay(d, date),
          onDayTap: (d) => setState(() => _date = d),
          onMonthChanged: (m) => setState(() => _month = m),
        ),
        _SelectedDateRow(
          date: date,
          onTap: date == null ? null : () => setState(() => _month = date),
        ),
        RideTimeField(
          label: 'Pick up at',
          value: _time,
          onChanged: (t) => setState(() => _time = t),
        ),
      ],
    );
  }
}

/// "Which days?" — any number of days plus the pick-up time. Tap a day to
/// add or remove it; a weekday chip adds (or removes) every such day of the
/// month on screen, from today on.
class WhichDaysSheet extends StatefulWidget {
  const WhichDaysSheet({super.key, this.initial, this.initialTime});

  final CustomSchedule? initial;
  final RideTime? initialTime;

  @override
  State<WhichDaysSheet> createState() => _WhichDaysSheetState();
}

class _WhichDaysSheetState extends State<WhichDaysSheet> {
  late final Set<DateTime> _dates = {...?widget.initial?.dates};
  late DateTime _month = widget.initial?.start ?? _today();
  late RideTime? _time = widget.initialTime;

  /// Sun … Sat, as in the Figma chips.
  static const List<int> _order = [
    DateTime.sunday,
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
  ];

  bool get _canFinish => _dates.isNotEmpty && _time != null;

  void _onDayTap(DateTime day) {
    final d = RideDateFormat.dateOnly(day);
    setState(() => _dates.contains(d) ? _dates.remove(d) : _dates.add(d));
  }

  bool _isSelected(DateTime day) =>
      _dates.contains(RideDateFormat.dateOnly(day));

  /// Days of [weekday] in the month on screen that can still be picked.
  List<DateTime> _weekdayDays(int weekday) {
    final today = _today();
    final last = DateTime(_month.year, _month.month + 1, 0).day;
    return [
      for (var day = 1; day <= last; day++)
        if (DateTime(_month.year, _month.month, day) case final d
            when d.weekday == weekday && !d.isBefore(today))
          d,
    ];
  }

  /// A chip is on when every pickable such day of the shown month is chosen.
  bool _weekdaySelected(int weekday) {
    final days = _weekdayDays(weekday);
    return days.isNotEmpty && days.every(_dates.contains);
  }

  void _toggleWeekday(int weekday) {
    final days = _weekdayDays(weekday);
    setState(() {
      _weekdaySelected(weekday) ? _dates.removeAll(days) : _dates.addAll(days);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AskRideSheet(
      title: 'Which days?',
      footer: _DoneButton(
        onPressed: _canFinish
            ? () => Navigator.of(
                context,
              ).pop<CustomSelection>((dates: {..._dates}, time: _time!))
            : null,
      ),
      children: [
        Row(
          children: [
            for (var i = 0; i < _order.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _WeekdayChip(
                  label: RideDateFormat.weekdayShort(_order[i]),
                  selected: _weekdaySelected(_order[i]),
                  onTap: () => _toggleWeekday(_order[i]),
                ),
              ),
            ],
          ],
        ),
        RideCalendar(
          month: _month,
          firstDate: _today(),
          isSelected: _isSelected,
          onDayTap: _onDayTap,
          onMonthChanged: (m) => setState(() => _month = m),
        ),
        RideTimeField(
          label: 'Pick up at',
          value: _time,
          onChanged: (t) => setState(() => _time = t),
        ),
      ],
    );
  }
}

class _WeekdayChip extends StatelessWidget {
  const _WeekdayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.ink : AppColors.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: 44,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: AskRideTextStyles.weekdayChip.copyWith(
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

class _SelectedDateRow extends StatelessWidget {
  const _SelectedDateRow({required this.date, required this.onTap});

  final DateTime? date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(kFieldRowRadius);
    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              SvgPicture.asset(AskRideAssets.calendar, width: 24, height: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Date',
                      style: AskRideTextStyles.selectDateCaption,
                    ),
                    Text(
                      date == null
                          ? 'Tap a day above'
                          : RideDateFormat.long(date!),
                      style: AskRideTextStyles.selectDateValue.copyWith(
                        color: date == null ? AppColors.textSecondary : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SvgPicture.asset(
                AskRideAssets.chevronRight,
                width: 22,
                height: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AskRideActionButton(
      label: 'Done',
      icon: AskRideAssets.check,
      onPressed: onPressed,
      height: 66,
      gap: 12,
      iconSize: 24,
      textStyle: AskRideTextStyles.doneButton,
    );
  }
}
