/// Display helpers for the Messages screens (no `intl` dependency).
abstract final class MessagesFormat {
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

  /// `8:30 AM`.
  static String clock(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
  }

  /// `Thu`.
  static String shortWeekday(DateTime time) =>
      _weekdays[time.weekday - 1].substring(0, 3);

  /// `Nov 2`.
  static String monthDay(DateTime time) =>
      '${_months[time.month - 1]} ${time.day}';

  /// `Thu · 8:30 AM` (request cards).
  static String dayAndTime(DateTime time) =>
      '${shortWeekday(time)} · ${clock(time)}';

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Chat list time: `8:32 AM` today, `Mon` this week, else `Nov 2`.
  static String listTime(DateTime at, {DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    final days = today.difference(_day(at)).inDays;
    if (days <= 0) return clock(at);
    if (days < 7) return shortWeekday(at);
    return monthDay(at);
  }

  /// Day separator in a thread: `Today`, `Yesterday`, `Monday`, `Nov 2`.
  static String dayLabel(DateTime at, {DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    final days = today.difference(_day(at)).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return _weekdays[at.weekday - 1];
    return monthDay(at);
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// `Emma`, `Emma & Noah`, `Emma, Noah & Mia`.
  static String names(List<String> names, {String fallback = 'their kids'}) {
    final list = names.where((n) => n.trim().isNotEmpty).toList();
    if (list.isEmpty) return fallback;
    if (list.length == 1) return list.first;
    return '${list.sublist(0, list.length - 1).join(', ')} & ${list.last}';
  }

  /// `1.1 mi`, `12 mi`.
  static String miles(double miles) =>
      miles >= 10 ? '${miles.round()} mi' : '${miles.toStringAsFixed(1)} mi';

  /// `JP` from `Jen Park`.
  static String initials(String first, [String? last]) {
    final a = first.trim().isEmpty ? '' : first.trim()[0];
    final b = (last ?? '').trim().isEmpty ? '' : last!.trim()[0];
    final value = '$a$b'.toUpperCase();
    return value.isEmpty ? '?' : value;
  }
}
