import 'package:equatable/equatable.dart';

import '../../core/constants/ride_tracking_api_constants.dart';
import '../../core/utils/ride_format.dart';

/// Where a ride stands on the server (`ride_requests.status`).
enum RideTrackingStatus {
  open,
  confirmed,
  inProgress,
  completed,
  cancelled,
  expired,
  missed;

  static RideTrackingStatus fromValue(Object? value) => switch (value) {
    'open' => open,
    'confirmed' => confirmed,
    'in_progress' => inProgress,
    'completed' => completed,
    'cancelled' => cancelled,
    'expired' => expired,
    'missed' => missed,
    _ => confirmed,
  };
}

/// A point on the map.
class GeoPoint extends Equatable {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  double metersTo(GeoPoint other) => RideFormat.distanceMeters(
    latitude,
    longitude,
    other.latitude,
    other.longitude,
  );

  @override
  List<Object?> get props => [latitude, longitude];
}

/// The Ride Partner's last reported position.
class RideLocation extends Equatable {
  const RideLocation({required this.point, this.heading, this.speed, this.at});

  final GeoPoint point;

  /// Degrees from north, and metres per second; null when the phone didn't
  /// say.
  final double? heading;
  final double? speed;
  final DateTime? at;

  @override
  List<Object?> get props => [point, heading, speed, at];
}

/// A named stop on the route: the pickup, the school or a custom drop-off.
class RideStop extends Equatable {
  const RideStop({required this.label, this.point});

  final String label;
  final GeoPoint? point;

  @override
  List<Object?> get props => [label, point];
}

/// A grown-up on the ride (the Ride Partner or the requesting parent).
class RidePerson extends Equatable {
  const RidePerson({
    this.id,
    required this.name,
    required this.initials,
    this.phone,
    this.carModel,
    this.plate,
  });

  final String? id;
  final String name;
  final String initials;
  final String? phone;
  final String? carModel;
  final String? plate;

  String get firstName => name.split(' ').first;

  /// `Jen P.`
  String get shortName {
    final parts = name.split(' ');
    if (parts.length < 2 || parts.last.isEmpty) return name;
    return '${parts.first} ${parts.last[0]}.';
  }

  /// `Blue Toyota · 5RTY 118`, or null when no car is on file.
  String? get vehicleLine {
    final parts = [
      carModel,
      plate,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  List<Object?> get props => [id, name, initials, phone, carModel, plate];
}

/// A kid on the ride.
class RideKid extends Equatable {
  const RideKid({required this.id, required this.firstName, this.photoUrl});

  final String id;
  final String firstName;

  /// Signed URL of the kid's photo, when the backend lets this user see it.
  final String? photoUrl;

  @override
  List<Object?> get props => [id, firstName, photoUrl];
}

/// F22 · Live tracking — `get_ride_tracking`, re-read every few seconds.
class RideTracking extends Equatable {
  const RideTracking({
    required this.requestId,
    required this.status,
    required this.isDriver,
    required this.pickupAt,
    this.estimatedDropoffAt,
    this.startedAt,
    this.pickedUpAt,
    this.completedAt,
    required this.pickup,
    required this.school,
    this.dropoff,
    this.location,
    this.distanceMiles,
    this.plannedTripMiles,
    this.rideMinutes,
    this.kids = const [],
    this.driver,
    this.parent,
    this.path = const [],
    this.sosOpen = false,
    this.rated = false,
  });

  final String requestId;
  final RideTrackingStatus status;

  /// True when the signed-in parent is the Ride Partner.
  final bool isDriver;
  final DateTime pickupAt;
  final DateTime? estimatedDropoffAt;
  final DateTime? startedAt;
  final DateTime? pickedUpAt;
  final DateTime? completedAt;
  final RideStop pickup;
  final RideStop school;

  /// Custom drop-off (`dropoff`); `null` → the ride goes to [school].
  final RideStop? dropoff;
  final RideLocation? location;

  /// Driven since pickup (or the planned trip when GPS was missing).
  final double? distanceMiles;
  final double? plannedTripMiles;
  final int? rideMinutes;
  final List<RideKid> kids;
  final RidePerson? driver;
  final RidePerson? parent;

  /// Points driven so far, oldest first.
  final List<GeoPoint> path;
  final bool sosOpen;

  /// The requesting parent already said thank you (`rate_ride`).
  final bool rated;

  bool get started => status == RideTrackingStatus.inProgress;
  bool get pickedUp => pickedUpAt != null;
  bool get completed => status == RideTrackingStatus.completed;

  /// Cancelled, expired or missed: nothing to track.
  bool get closed =>
      status == RideTrackingStatus.cancelled ||
      status == RideTrackingStatus.expired ||
      status == RideTrackingStatus.missed;

  /// Where the kids are dropped off: the custom drop-off, else the school.
  RideStop get destination => dropoff ?? school;

  /// The ride goes to a place picked on the map, not the school.
  bool get hasCustomDropoff => dropoff != null;

  /// Where the car is heading next: the pickup, then [destination].
  RideStop get nextStop => pickedUp ? destination : pickup;

  List<String> get kidNames => [for (final k in kids) k.firstName];

  /// Straight-line meters from the car to [nextStop], when both are known.
  double? get metersToGo {
    final from = location?.point;
    final to = nextStop.point;
    if (from == null || to == null) return null;
    return from.metersTo(to);
  }

  /// The car is inside the [destination] geofence.
  bool get inSchoolZone {
    final from = location?.point;
    final to = destination.point;
    if (from == null || to == null) return false;
    return from.metersTo(to) <= RideTrackingApiConstants.schoolZoneMeters * 5;
  }

  /// Minutes until the car reaches [nextStop]: from the remaining distance
  /// at town speed, else from the planned times.
  int? minutesToGo({DateTime? now}) {
    final meters = metersToGo;
    if (meters != null) {
      // ~20 mph average with a 1.3 road-vs-straight-line factor.
      const metersPerMinute = 20 * RideFormat.metersPerMile / 60;
      return (meters * 1.3 / metersPerMinute).ceil().clamp(1, 600);
    }
    final target = pickedUp ? estimatedDropoffAt : pickupAt;
    if (target == null) return null;
    final diff = target.difference(now ?? DateTime.now()).inMinutes;
    return diff < 1 ? 1 : diff;
  }

  /// Trip time once dropped off.
  int? get tripMinutes {
    if (rideMinutes != null) return rideMinutes;
    final from = pickedUpAt;
    final to = completedAt;
    if (from == null || to == null) return null;
    return (to.difference(from).inSeconds / 60).ceil();
  }

  RideTracking copyWith({List<GeoPoint>? path}) => RideTracking(
    requestId: requestId,
    status: status,
    isDriver: isDriver,
    pickupAt: pickupAt,
    estimatedDropoffAt: estimatedDropoffAt,
    startedAt: startedAt,
    pickedUpAt: pickedUpAt,
    completedAt: completedAt,
    pickup: pickup,
    school: school,
    dropoff: dropoff,
    location: location,
    distanceMiles: distanceMiles,
    plannedTripMiles: plannedTripMiles,
    rideMinutes: rideMinutes,
    kids: kids,
    driver: driver,
    parent: parent,
    path: path ?? this.path,
    sosOpen: sosOpen,
    rated: rated,
  );

  @override
  List<Object?> get props => [
    requestId,
    status,
    isDriver,
    pickupAt,
    estimatedDropoffAt,
    startedAt,
    pickedUpAt,
    completedAt,
    pickup,
    school,
    dropoff,
    location,
    distanceMiles,
    plannedTripMiles,
    rideMinutes,
    kids,
    driver,
    parent,
    path,
    sosOpen,
    rated,
  ];
}

/// What `complete_ride` reports back.
class RideCompletion extends Equatable {
  const RideCompletion({
    this.completedAt,
    this.distanceMiles,
    this.rideMinutes,
    this.distanceFromSchoolMeters,
  });

  final DateTime? completedAt;
  final double? distanceMiles;
  final int? rideMinutes;
  final double? distanceFromSchoolMeters;

  @override
  List<Object?> get props => [
    completedAt,
    distanceMiles,
    rideMinutes,
    distanceFromSchoolMeters,
  ];
}
