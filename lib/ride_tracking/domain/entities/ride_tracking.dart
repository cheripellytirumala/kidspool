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
    this.carSeats,
    this.carColor,
    this.carYear,
    this.kidsOnRide,
    this.gender,
  });

  final String? id;
  final String name;
  final String initials;
  final String? phone;
  final String? carModel;
  final String? plate;

  /// All seats in the driver's car (5 = a 5-seater), when saved.
  final int? carSeats;
  final String? carColor;
  final int? carYear;

  /// Kids riding on this trip (seats taken besides the driver's).
  final int? kidsOnRide;

  /// `female` | `male` | `non_binary` | `prefer_not_to_say`, when set.
  final String? gender;

  /// "Female", "Male", "Non-binary"; null when not set or not shared.
  String? get genderLabel => switch (gender) {
    'female' => 'Female',
    'male' => 'Male',
    'non_binary' => 'Non-binary',
    _ => null,
  };

  /// `Silver 2021 Toyota Innova` — what to look for at the kerb.
  String? get carDescription {
    final parts = [
      carColor,
      carYear?.toString(),
      carModel,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// `2 of 6 kid seats taken` (all seats minus the driver's).
  String? get seatsLine {
    final seats = carSeats;
    if (seats == null || seats < 2) return null;
    final kidSeats = seats - 1;
    final taken = kidsOnRide;
    return taken == null
        ? '$kidSeats kid seats'
        : '$taken of $kidSeats kid seats taken';
  }

  String get firstName => name.split(' ').first;

  /// `Jen P.`
  String get shortName {
    final parts = name.split(' ');
    if (parts.length < 2 || parts.last.isEmpty) return name;
    return '${parts.first} ${parts.last[0]}.';
  }

  /// `Blue Toyota · 5RTY 118 · 7-seater`, or null when no car is on file.
  String? get vehicleLine {
    final parts = [
      carDescription,
      plate,
      if (carSeats != null) '$carSeats-seater',
    ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  List<Object?> get props => [
    id,
    name,
    initials,
    phone,
    carModel,
    plate,
    carSeats,
    carColor,
    carYear,
    kidsOnRide,
    gender,
  ];
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
    this.pickupPin,
    this.pinRequired = false,
    this.cancelledAt,
    this.cancelledBy,
    this.cancelReason,
    this.autoEndedAt,
    this.overdueAt,
    this.autoEndAt,
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

  /// 4-digit code the requesting parent gives the Ride Partner at pick-up
  /// (only sent to that parent, until pick-up).
  final String? pickupPin;

  /// The server refuses "Picked up" without the parent's PIN.
  final bool pinRequired;

  final DateTime? cancelledAt;

  /// `parent` | `driver` | `system` (auto-ended), for a cancelled ride.
  final String? cancelledBy;
  final String? cancelReason;

  /// Closed by the server because it ran too long.
  final DateTime? autoEndedAt;

  /// From here on the ride counts as running late (1 h past drop-off).
  final DateTime? overdueAt;

  /// The server closes the ride by itself at this time (3 h after start).
  final DateTime? autoEndAt;

  /// Started but the kids aren't in the car yet: either side may cancel.
  bool get canCancelBeforePickup => started && !pickedUp;

  /// Still in progress past [overdueAt].
  bool overdue({DateTime? now}) {
    final at = overdueAt;
    return started && at != null && !(now ?? DateTime.now()).isBefore(at);
  }

  bool get autoEnded => autoEndedAt != null;

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

  RideTracking copyWith({List<GeoPoint>? path, RideLocation? location}) =>
      RideTracking(
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
        location: location ?? this.location,
        distanceMiles: distanceMiles,
        plannedTripMiles: plannedTripMiles,
        rideMinutes: rideMinutes,
        kids: kids,
        driver: driver,
        parent: parent,
        path: path ?? this.path,
        sosOpen: sosOpen,
        pickupPin: pickupPin,
        pinRequired: pinRequired,
        cancelledAt: cancelledAt,
        cancelledBy: cancelledBy,
        cancelReason: cancelReason,
        autoEndedAt: autoEndedAt,
        overdueAt: overdueAt,
        autoEndAt: autoEndAt,
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
    pickupPin,
    pinRequired,
    cancelledAt,
    cancelledBy,
    cancelReason,
    autoEndedAt,
    overdueAt,
    autoEndAt,
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
