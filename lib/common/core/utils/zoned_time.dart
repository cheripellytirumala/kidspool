import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Shows an instant on the clock of a given IANA time zone, e.g. a ride's
/// pickup in the ride's own zone (11:20 AM in New York), not converted to
/// whatever zone the phone is set to.
abstract final class ZonedTime {
  static bool _ready = false;

  /// [utc] as a time whose hour/minute are those of [zone]; the phone's
  /// local time when the zone is missing or unknown.
  static DateTime inZone(DateTime utc, String? zone) {
    if (zone == null || zone.trim().isEmpty) return utc.toLocal();
    try {
      if (!_ready) {
        tzdata.initializeTimeZones();
        _ready = true;
      }
      return tz.TZDateTime.from(utc, tz.getLocation(zone.trim()));
    } catch (_) {
      return utc.toLocal();
    }
  }
}
