/// F25b time labels: `now`, `2m`, `1h`, `Wed`, `Oct 12`.
abstract final class NotificationTime {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
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

  static String label(DateTime at, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final diff = current.difference(at);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    final today = DateTime(current.year, current.month, current.day);
    final day = DateTime(at.year, at.month, at.day);
    if (today.difference(day).inDays < 7) return _weekdays[at.weekday - 1];
    final date = '${_months[at.month - 1]} ${at.day}';
    return at.year == current.year ? date : '$date, ${at.year}';
  }

  /// Spoken form for screen readers.
  static String spoken(DateTime at, {DateTime? now}) {
    final short = label(at, now: now);
    final m = RegExp(r'^(\d+)([mh])$').firstMatch(short);
    if (m == null) return short;
    final n = int.parse(m.group(1)!);
    final unit = m.group(2) == 'm' ? 'minute' : 'hour';
    return '$n $unit${n == 1 ? '' : 's'} ago';
  }
}
