/// One GPS fix from the phone, as the ride RPCs take it.
class RideFix {
  const RideFix({
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
    this.accuracy,
  });

  final double latitude;
  final double longitude;

  /// Degrees from north; null when unknown.
  final double? heading;

  /// Metres per second; null when unknown.
  final double? speed;

  /// Metres; null when unknown.
  final double? accuracy;

  /// `{latitude, longitude}` for `start_ride` / `mark_picked_up` /
  /// `complete_ride` / `trigger_sos`.
  Map<String, dynamic> toPointParams() => {
    'latitude': latitude,
    'longitude': longitude,
  };

  /// Full fix for `update_ride_location`.
  Map<String, dynamic> toLocationParams() => {
    ...toPointParams(),
    if (heading != null && heading! >= 0) 'heading': heading,
    if (speed != null && speed! >= 0) 'speed': speed,
    if (accuracy != null && accuracy! > 0) 'accuracy': accuracy,
  };
}
