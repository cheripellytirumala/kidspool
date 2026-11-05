import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// [home]: a saved pick-up address; [school]: a kid's school; [custom]: any
/// place picked from Google search as the drop-off.
enum PlaceKind { home, school, custom }

/// A place the family saved earlier (home, school, activity), or a custom
/// drop-off found with Google search.
class SavedPlace extends Equatable {
  const SavedPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.kind,
    this.detail,
    this.latitude,
    this.longitude,
    this.addressLine1 = '',
    this.city = '',
    this.state = '',
    this.zip = '',
  });

  /// e.g. `Home · 24 Maple St`, `Lincoln Elementary`.
  final String name;
  final String id;
  final String address;
  final PlaceKind kind;

  /// Extra context shown under the address, e.g. `school starts 9:00 AM`.
  final String? detail;

  /// Coordinates, when known (saved addresses and custom drop-offs).
  final double? latitude;
  final double? longitude;

  /// Address parts of a custom drop-off (sent as `dropoffAddress`).
  final String addressLine1;
  final String city;
  final String state;
  final String zip;

  bool get isCustom => kind == PlaceKind.custom;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// Straight-line metres to [other]; `null` when either has no coordinates.
  double? metersTo(SavedPlace other) {
    if (!hasCoordinates || !other.hasCoordinates) return null;
    const earthRadius = 6371000.0;
    double rad(double deg) => deg * math.pi / 180;
    final dLat = rad(other.latitude! - latitude!);
    final dLng = rad(other.longitude! - longitude!);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(latitude!)) *
            math.cos(rad(other.latitude!)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadius * math.asin(math.sqrt(a.toDouble()));
  }

  @override
  List<Object?> get props => [
    id,
    name,
    address,
    kind,
    detail,
    latitude,
    longitude,
    addressLine1,
    city,
    state,
    zip,
  ];
}
