import 'package:equatable/equatable.dart';

/// How often the ride is needed: a single day, or any chosen days.
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

/// Any set of days the parent picked in "Which days?" (need not be
/// consecutive).
class CustomSchedule extends RideSchedule {
  CustomSchedule(Iterable<DateTime> dates)
    : dates = List.unmodifiable(
        {for (final d in dates) DateTime(d.year, d.month, d.day)}.toList()
          ..sort(),
      );

  /// The chosen days, date-only, unique and in order.
  final List<DateTime> dates;

  /// First and last chosen day; `null` when nothing is chosen.
  DateTime? get start => dates.isEmpty ? null : dates.first;
  DateTime? get end => dates.isEmpty ? null : dates.last;

  bool includes(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return dates.contains(d);
  }

  @override
  List<DateTime> get rideDates => dates;

  @override
  List<Object?> get props => [dates];
}
