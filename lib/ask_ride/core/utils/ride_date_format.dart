/// Small date formatter for the ride form (the app does not bundle `intl`).
abstract final class RideDateFormat {
  static const List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// `Wednesday, Nov 4`
  static String long(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';

  /// `Wed, Nov 4`
  static String short(DateTime d) =>
      '${weekdayShort(d.weekday)}, ${_months[d.month - 1]} ${d.day}';

  /// `Nov 2026`
  static String monthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';

  /// `Mon` for [DateTime.monday].
  static String weekdayShort(int weekday) =>
      _weekdays[weekday - 1].substring(0, 3);

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
