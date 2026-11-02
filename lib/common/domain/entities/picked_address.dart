import 'package:equatable/equatable.dart';

/// An address chosen on the map, with coordinates.
class PickedAddress extends Equatable {
  const PickedAddress({
    required this.latitude,
    required this.longitude,
    this.street = '',
    this.city = '',
    this.stateCode = '',
    this.zip = '',
    this.formatted = '',
    this.name,
  });

  final double latitude;
  final double longitude;
  final String street;
  final String city;
  final String stateCode;
  final String zip;

  /// Full one-line address from Google, used when parts are missing.
  final String formatted;

  /// Place name for points of interest, e.g. `Lincoln Elementary`.
  final String? name;

  /// Main line shown to the user.
  String get title {
    if (name != null && name!.isNotEmpty && name != street) return name!;
    if (street.isNotEmpty) return street;
    return formatted.split(',').first;
  }

  /// Secondary line: `City, ST 12345`.
  String get subtitle {
    final region = [stateCode, zip].where((p) => p.isNotEmpty).join(' ');
    final parts = [city, region].where((p) => p.isNotEmpty).join(', ');
    return parts.isNotEmpty ? parts : formatted;
  }

  /// Enough detail to save as a pick-up / drop-off address.
  bool get isComplete => street.isNotEmpty && city.isNotEmpty;

  @override
  List<Object?> get props => [
    latitude,
    longitude,
    street,
    city,
    stateCode,
    zip,
    formatted,
    name,
  ];
}
