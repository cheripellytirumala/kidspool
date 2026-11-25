import 'ride_time.dart';

/// A pick-up can't be in the past (no minimum notice), counted from the
/// phone's current time.
abstract final class RideLeadTime {
  static const Duration minimum = Duration.zero;

  /// The first pick-up allowed if the ride were asked for at [now].
  static DateTime earliest(DateTime now) => now.add(minimum);

  /// Pick-up on [date] (only the day is used) at [time].
  static DateTime pickupAt(DateTime date, RideTime time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  /// Whether a pick-up on [date] at [time] has already passed.
  static bool isTooSoon(DateTime date, RideTime time, {DateTime? now}) =>
      pickupAt(date, time).isBefore(earliest(now ?? DateTime.now()));

  /// Hint shown when the earliest of [dates] at [time] is too soon, or null.
  static String? tooSoonMessage(
    Iterable<DateTime> dates,
    RideTime time, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    if (!dates.any((d) => isTooSoon(d, time, now: current))) return null;
    final first = earliest(current);
    final sameDay = dates.any(
      (d) =>
          d.year == current.year &&
          d.month == current.month &&
          d.day == current.day,
    );
    final at = RideTime(first.hour, first.minute).format();
    return sameDay && first.day == current.day
        ? 'That time has passed. Today, pick a time after $at.'
        : 'That time has passed. Pick a later day or time.';
  }
}
