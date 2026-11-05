import '../../../common/core/error/exceptions.dart';
import '../../../common/core/utils/json_parser.dart';
import '../../core/utils/ride_format.dart';
import '../../domain/entities/ride_tracking.dart';

/// Parses `get_ride_tracking` / `complete_ride` responses.
abstract final class RideTrackingModel {
  /// Photo paths of the kids in a `get_ride_tracking` response, to sign.
  static List<String> kidPhotoPaths(Map<String, dynamic> json) => [
    for (final k in json['kids'] as List? ?? const [])
      if (k is Map &&
          k['photoPath'] is String &&
          (k['photoPath'] as String).isNotEmpty)
        k['photoPath'] as String,
  ];

  /// [photoUrls] maps `photoPath` → signed URL.
  static RideTracking fromJson(
    Map<String, dynamic> json, {
    Map<String, String> photoUrls = const {},
  }) {
    final requestId = json.readString('requestId');
    if (requestId == null) throw const ParsingException();

    final school = _map(json['school']);
    final dropoff = _map(json['dropoff']);
    final address = _map(json['pickupAddress']);
    final location = _map(json['currentLocation']);
    final locationPoint = _point(location);
    final pickupLabel = [address['label'], address['addressLine1']]
        .whereType<String>()
        .map((s) => s.trim())
        .firstWhere((s) => s.isNotEmpty, orElse: () => 'Home');

    return RideTracking(
      requestId: requestId,
      status: RideTrackingStatus.fromValue(json['status']),
      isDriver: json['myRole'] == 'driver',
      pickupAt: _time(json['pickupAt']) ?? DateTime.now(),
      estimatedDropoffAt: _time(json['estimatedDropoffAt']),
      startedAt: _time(json['startedAt']),
      pickedUpAt: _time(json['pickedUpAt']),
      completedAt: _time(json['completedAt']),
      pickup: RideStop(label: pickupLabel, point: _point(address)),
      school: RideStop(
        label: school.readString('name') ?? 'School',
        point: _point(school),
      ),
      dropoff: _dropoff(dropoff),
      location: locationPoint == null
          ? null
          : RideLocation(
              point: locationPoint,
              heading: location.readDouble('heading'),
              speed: location.readDouble('speed'),
              at: _time(location['at']),
            ),
      distanceMiles: json.readDouble('distanceMiles'),
      plannedTripMiles: json.readDouble('plannedTripMiles'),
      rideMinutes: json.readInt('rideMinutes'),
      kids: [
        for (final k in json['kids'] as List? ?? const [])
          if (k is Map && k['firstName'] is String)
            RideKid(
              id: k['id']?.toString() ?? k['firstName'] as String,
              firstName: k['firstName'] as String,
              photoUrl: photoUrls[k['photoPath']],
            ),
      ],
      driver: _person(_map(json['driver']), fallback: 'Ride Partner'),
      parent: _person(_map(json['parent']), fallback: 'Parent'),
      path: [
        for (final p in json['path'] as List? ?? const [])
          if (p is List && p.length == 2 && p[0] is num && p[1] is num)
            GeoPoint((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ],
      sosOpen: json['openSos'] is Map,
      rated: json['rating'] is Map,
    );
  }

  static RideCompletion completionFromJson(Object? json) {
    if (json is! Map) return const RideCompletion();
    final map = Map<String, dynamic>.from(json);
    return RideCompletion(
      completedAt: _time(map['completedAt']),
      distanceMiles: map.readDouble('distanceMiles'),
      rideMinutes: map.readInt('rideMinutes'),
      distanceFromSchoolMeters: map.readDouble('distanceFromSchoolMeters'),
    );
  }

  static RidePerson? _person(
    Map<String, dynamic> m, {
    required String fallback,
  }) {
    if (m.isEmpty) return null;
    final name = [m['firstName'], m['lastName']]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(' ');
    final vehicle = _map(m['vehicle']);
    final display = name.isEmpty ? fallback : name;
    return RidePerson(
      id: m.readString('id'),
      name: display,
      initials: m.readString('initials') ?? RideFormat.initials(display),
      phone: m.readString('phone'),
      carModel: vehicle.readString('model'),
      plate: vehicle.readString('plateNumber'),
    );
  }

  /// `dropoff` `{label, addressLine1, …, latitude, longitude}`; `null` (or
  /// no coordinates) → the ride goes to the school.
  static RideStop? _dropoff(Map<String, dynamic> m) {
    final point = _point(m);
    if (point == null) return null;
    final label = [m['label'], m['addressLine1']]
        .whereType<String>()
        .map((s) => s.trim())
        .firstWhere((s) => s.isNotEmpty, orElse: () => 'Drop-off');
    return RideStop(label: label, point: point);
  }

  static Map<String, dynamic> _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : const {};

  static GeoPoint? _point(Map<String, dynamic> m) {
    final lat = m.readDouble('latitude');
    final lng = m.readDouble('longitude');
    return lat == null || lng == null ? null : GeoPoint(lat, lng);
  }

  static DateTime? _time(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;
}
