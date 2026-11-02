import 'dart:math' as math;

/// Display helpers for ride-day screens (no `intl` dependency).
abstract final class RideFormat {
  /// `8:32 AM`.
  static String clock(DateTime time) => '${shortClock(time)} ${meridiem(time)}';

  /// `8:32` (no AM/PM), for the big stat numbers.
  static String shortClock(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    return '$hour:${time.minute.toString().padLeft(2, '0')}';
  }

  static String meridiem(DateTime time) => time.hour < 12 ? 'AM' : 'PM';

  /// `Emma`, `Emma & Noah`, `Emma, Noah & Mia`.
  static String names(List<String> names, {String fallback = 'Your kids'}) {
    final list = names.where((n) => n.trim().isNotEmpty).toList();
    if (list.isEmpty) return fallback;
    if (list.length == 1) return list.first;
    return '${list.sublist(0, list.length - 1).join(', ')} & ${list.last}';
  }

  /// `1.1 mi`, `0.2 mi`, `12 mi`.
  static String miles(double miles) {
    if (miles >= 10) return '${miles.round()} mi';
    return '${miles.toStringAsFixed(1)} mi';
  }

  /// `6 min`, `1 h 05 min`.
  static String minutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')} min';
  }

  /// Human time since [at]: `now`, `2 min ago`, `8:32 AM`.
  static String ago(DateTime at, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(at);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return clock(at);
  }

  /// `JP` from `Jen Park`.
  static String initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  /// Great-circle distance in meters.
  static double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earth = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earth * math.asin(math.min(1, math.sqrt(a)));
  }

  static const double metersPerMile = 1609.344;
}
