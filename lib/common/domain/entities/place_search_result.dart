import 'package:equatable/equatable.dart';

/// One Google Places Text Search result (a school, club, studio…), with the
/// address split into parts so it can be saved.
class PlaceSearchResult extends Equatable {
  const PlaceSearchResult({
    required this.placeId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.formattedAddress = '',
    this.shortAddress = '',
    this.street = '',
    this.city = '',
    this.stateCode = '',
    this.zip = '',
    this.primaryType,
  });

  /// Google place id, e.g. `ChIJ…`.
  final String placeId;
  final String name;
  final double latitude;
  final double longitude;

  /// e.g. `1200 Valencia St, San Francisco, CA 94110, USA`.
  final String formattedAddress;

  /// e.g. `1200 Valencia St, San Francisco`.
  final String shortAddress;

  /// Street number + route, e.g. `1200 Valencia St`. Empty when unknown.
  final String street;
  final String city;
  final String stateCode;
  final String zip;

  /// Google's primary place type, e.g. `primary_school`, `swimming_pool`.
  final String? primaryType;

  @override
  List<Object?> get props => [
    placeId,
    name,
    latitude,
    longitude,
    formattedAddress,
    shortAddress,
    street,
    city,
    stateCode,
    zip,
    primaryType,
  ];
}
