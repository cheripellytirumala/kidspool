import 'package:equatable/equatable.dart';

/// How often the ride is needed: a single day, or chosen weekdays between two
/// dates.
sealed class RideSchedule extends Equatable {
  const RideSchedule();

  /// Every day a ride is needed, in order.
  List<DateTime> get rideDates;
}

class OnceSchedule extends RideSchedule {
  const OnceSchedule(this.date);

  final DateTime date;

  @override
  List<DateTime> get rideDates => [date];

  @override
  List<Object?> get props => [date];
}

class CustomSchedule extends RideSchedule {
  const CustomSchedule({
    required this.start,
    required this.end,
    required this.weekdays,
  });

  final DateTime start;
  final DateTime end;

  /// [DateTime.monday] … [DateTime.sunday]. Empty means every day.
  final Set<int> weekdays;

  bool includes(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    if (d.isBefore(start) || d.isAfter(end)) return false;
    return weekdays.isEmpty || weekdays.contains(d.weekday);
  }

  @override
  List<DateTime> get rideDates => [
    for (
      var d = start;
      !d.isAfter(end);
      d = DateTime(d.year, d.month, d.day + 1)
    )
      if (includes(d)) d,
  ];

  @override
  List<Object?> get props => [start, end, weekdays.toList()..sort()];
}
