import 'package:equatable/equatable.dart';

/// Time of day for a pick-up, kept free of Flutter types (24h clock).
class RideTime extends Equatable implements Comparable<RideTime> {
  const RideTime(this.hour, this.minute)
    : assert(hour >= 0 && hour < 24),
      assert(minute >= 0 && minute < 60);

  final int hour;
  final int minute;

  /// Parses what a parent types: `8:30 AM`, `8:30am`, `830`, `8 pm`,
  /// `15:30`, `3.30 PM`. Returns `null` when the text is not a valid time.
  static RideTime? tryParse(String input) {
    final text = input.trim().toLowerCase().replaceAll('.', ':');
    final match = RegExp(
      r'^(\d{1,2})(?::?(\d{2}))?\s*([ap])?\.?\s*m?\.?$',
    ).firstMatch(text);
    if (match == null) return null;

    var hour = int.parse(match.group(1)!);
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    final meridiem = match.group(3);
    if (minute > 59) return null;

    if (meridiem != null) {
      if (hour < 1 || hour > 12) return null;
      if (meridiem == 'a' && hour == 12) hour = 0;
      if (meridiem == 'p' && hour != 12) hour += 12;
    } else if (hour > 23) {
      return null;
    }
    return RideTime(hour, minute);
  }

  /// `8:30 AM`
  String format() {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m ${hour < 12 ? 'AM' : 'PM'}';
  }

  int get minutesOfDay => hour * 60 + minute;

  @override
  int compareTo(RideTime other) => minutesOfDay.compareTo(other.minutesOfDay);

  @override
  List<Object?> get props => [hour, minute];

  @override
  String toString() => format();
}
