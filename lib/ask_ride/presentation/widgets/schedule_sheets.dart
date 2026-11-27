import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../core/constants/ask_ride_assets.dart';
import '../../core/utils/ride_date_format.dart';
import '../../domain/entities/ride_lead_time.dart';
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

  /// Week on screen: starts today, or on the week of the picked day.
  late DateTime _week = RideCalendar.weekOf(_date ?? _today(), _today());
  late RideTime? _time = widget.initialTime;

  /// "That time has already passed" while the pick-up is in the past.
  String? get _tooSoon => _date == null || _time == null
      ? null
      : RideLeadTime.tooSoonMessage([_date!], _time!);

  bool get _canFinish => _date != null && _time != null && _tooSoon == null;

  @override
  Widget build(BuildContext context) {
    final date = _date;
    final tooSoon = _tooSoon;
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
          start: _week,
          firstDate: _today(),
          isSelected: (d) => date != null && RideDateFormat.isSameDay(d, date),
          onDayTap: (d) => setState(() => _date = d),
          onWeekChanged: (w) => setState(() => _week = w),
        ),
        _SelectedDateRow(
          date: date,
          onTap: date == null
              ? null
              : () =>
                    setState(() => _week = RideCalendar.weekOf(date, _today())),
        ),
        RideTimeField(
          label: 'Pick up at',
          value: _time,
          onChanged: (t) => setState(() => _time = t),
        ),
        if (tooSoon != null) _TooSoonHint(tooSoon),
      ],
    );
  }
}

/// "Which days?" — any number of days plus the pick-up time. Tap a day to
/// add or remove it; a weekday chip adds (or removes) that weekday in the
/// week on screen and the [chipWeeks] - 1 weeks after it.
class WhichDaysSheet extends StatefulWidget {
  const WhichDaysSheet({
    super.key,
    this.initial,
    this.initialTime,
    this.maxDays = 20,
  });

  /// Most days one request can hold (server: `rides (1–20 days)`).
  final int maxDays;

  final CustomSchedule? initial;
  final RideTime? initialTime;

  @override
  State<WhichDaysSheet> createState() => _WhichDaysSheetState();
}

class _WhichDaysSheetState extends State<WhichDaysSheet> {
  late final Set<DateTime> _dates = {...?widget.initial?.dates};

  /// Week on screen: starts today, or on the week of the first picked day.
  late DateTime _week = RideCalendar.weekOf(
    widget.initial?.start ?? _today(),
    _today(),
  );

  /// A weekday chip repeats over this many weeks.
  static const int chipWeeks = 4;
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

  String? get _tooSoon =>
      _time == null ? null : RideLeadTime.tooSoonMessage(_dates, _time!);

  /// Set when a tap or chip wanted more than [WhichDaysSheet.maxDays].
  bool _hitLimit = false;

  bool get _overLimit => _dates.length > widget.maxDays;

  bool get _canFinish =>
      _dates.isNotEmpty && !_overLimit && _time != null && _tooSoon == null;

  void _onDayTap(DateTime day) {
    final d = RideDateFormat.dateOnly(day);
    setState(() {
      if (_dates.remove(d)) {
        _hitLimit = false;
      } else if (_dates.length >= widget.maxDays) {
        _hitLimit = true;
      } else {
        _dates.add(d);
      }
    });
  }

  bool _isSelected(DateTime day) =>
      _dates.contains(RideDateFormat.dateOnly(day));

  /// Days of [weekday] from the week on screen over [chipWeeks] weeks, not
  /// counting today once its pick-up time is too close.
  List<DateTime> _weekdayDays(int weekday) => [
    for (var i = 0; i < chipWeeks * RideCalendar.days; i++)
      if (DateTime(_week.year, _week.month, _week.day + i) case final d
          when d.weekday == weekday &&
              // Skip today when its pick-up time has already passed.
              (_time == null || !RideLeadTime.isTooSoon(d, _time!)))
        d,
  ];

  /// A chip is on when every such day of those weeks is chosen.
  bool _weekdaySelected(int weekday) {
    final days = _weekdayDays(weekday);
    return days.isNotEmpty && days.every(_dates.contains);
  }

  void _toggleWeekday(int weekday) {
    final days = _weekdayDays(weekday);
    setState(() {
      if (_weekdaySelected(weekday)) {
        _dates.removeAll(days);
        _hitLimit = false;
        return;
      }
      // Earliest first, only while there is room.
      for (final d in days) {
        if (_dates.contains(d)) continue;
        if (_dates.length >= widget.maxDays) {
          _hitLimit = true;
          break;
        }
        _dates.add(d);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tooSoon = _tooSoon;
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
          start: _week,
          firstDate: _today(),
          isSelected: _isSelected,
          onDayTap: _onDayTap,
          onWeekChanged: (w) => setState(() => _week = w),
        ),
        if (_dates.isNotEmpty) _PickedDays(_dates, max: widget.maxDays),
        if (_hitLimit || _overLimit)
          _TooSoonHint(
            'A request can have up to ${widget.maxDays} days. '
            'Remove some days, or ask again for later dates.',
          ),
        RideTimeField(
          label: 'Pick up at',
          value: _time,
          onChanged: (t) => setState(() => _time = t),
        ),
        if (tooSoon != null) _TooSoonHint(tooSoon),
      ],
    );
  }
}

/// "5 of 20 days picked · Wed, Nov 26 to …": days outside the week on screen
/// (weekday chips cover 4 weeks) are still counted.
class _PickedDays extends StatelessWidget {
  const _PickedDays(this.dates, {required this.max});

  final Set<DateTime> dates;
  final int max;

  @override
  Widget build(BuildContext context) {
    final sorted = dates.toList()..sort();
    final n = sorted.length;
    return Text(
      '$n of $max days picked · '
      '${RideDateFormat.short(sorted.first)}'
      '${n > 1 ? ' to ${RideDateFormat.short(sorted.last)}' : ''}',
      style: AskRideTextStyles.fieldCaption,
    );
  }
}

/// Red line under the time: the pick-up has already passed.
class _TooSoonHint extends StatelessWidget {
  const _TooSoonHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.schedule_rounded, size: 18, color: AppColors.danger),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: AskRideTextStyles.fieldCaption.copyWith(
              color: AppColors.danger,
            ),
          ),
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
