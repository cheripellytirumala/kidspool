import 'package:flutter_timezone/flutter_timezone.dart';

/// IANA time zone of the device (e.g. `America/Los_Angeles`), required by
/// the ride request RPCs.
class TimeZoneService {
  String? _cached;

  Future<String> current() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      return _cached = info.identifier;
    } on Exception catch (_) {
      return 'America/Los_Angeles';
    }
  }
}
