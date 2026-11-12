import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../error/exceptions.dart';

/// An address with coordinates, as required by the `add_address` RPC.
class ResolvedAddress {
  const ResolvedAddress({
    required this.latitude,
    required this.longitude,
    this.street = '',
    this.city = '',
    this.stateCode = '',
    this.zip = '',
  });

  final double latitude;
  final double longitude;
  final String street;
  final String city;
  final String stateCode;
  final String zip;
}

/// Device location and the OS geocoder (no backend calls).
class LocationService {
  LocationService([this._override]);

  final Geocoding? _override;

  // Created on first use: the platform geocoder isn't available in tests.
  late final Geocoding _geocoding = _override ?? Geocoding();

  /// Current GPS position, reverse-geocoded into an address.
  Future<ResolvedAddress> currentAddress() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const DeviceException('Turn on Location Services to use this.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const DeviceException(
        'Allow location access in Settings, or type your address.',
      );
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } on Exception catch (_) {
      // No fresh fix (weak signal, or a simulator without a location):
      // use the last one the phone knows.
      try {
        position = await Geolocator.getLastKnownPosition();
      } on Exception catch (_) {
        position = null;
      }
    }
    if (position == null) {
      throw const DeviceException(
        'We couldn’t find your location. Search your address or move the pin.',
      );
    }

    try {
      final marks = await _geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final mark = marks.isEmpty ? null : marks.first;
      final street = [
        mark?.subThoroughfare,
        mark?.thoroughfare,
      ].where((p) => p != null && p.trim().isNotEmpty).join(' ');
      return ResolvedAddress(
        latitude: position.latitude,
        longitude: position.longitude,
        street: street.isNotEmpty ? street : (mark?.street ?? ''),
        city: mark?.locality ?? '',
        stateCode: mark?.administrativeArea ?? '',
        zip: mark?.postalCode ?? '',
      );
    } on Exception catch (_) {
      // Coordinates are what matter; the user can type the rest.
      return ResolvedAddress(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }
  }

  /// Reverse-geocodes a map position (e.g. where the user dropped the pin).
  /// Always returns the coordinates; address parts are blank if unknown.
  Future<ResolvedAddress> addressAt(double latitude, double longitude) async {
    try {
      final marks = await _geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );
      final mark = marks.isEmpty ? null : marks.first;
      final street = [
        mark?.subThoroughfare,
        mark?.thoroughfare,
      ].where((p) => p != null && p.trim().isNotEmpty).join(' ');
      return ResolvedAddress(
        latitude: latitude,
        longitude: longitude,
        street: street.isNotEmpty ? street : (mark?.street ?? mark?.name ?? ''),
        city: mark?.locality?.isNotEmpty == true
            ? mark!.locality!
            : (mark?.subAdministrativeArea ?? ''),
        stateCode: mark?.administrativeArea ?? '',
        zip: mark?.postalCode ?? '',
      );
    } on Exception catch (_) {
      return ResolvedAddress(latitude: latitude, longitude: longitude);
    }
  }

  /// Coordinates of a typed address.
  Future<ResolvedAddress> geocode({
    required String street,
    required String city,
    required String stateCode,
    required String zip,
  }) async {
    final query = '$street, $city, $stateCode $zip, USA';
    try {
      final locations = await _geocoding.locationFromAddress(query);
      if (locations.isNotEmpty) {
        final l = locations.first;
        return ResolvedAddress(
          latitude: l.latitude,
          longitude: l.longitude,
          street: street,
          city: city,
          stateCode: stateCode,
          zip: zip,
        );
      }
    } on Exception catch (_) {
      // Fall through to the error below.
    }
    throw const DeviceException(
      'We couldn’t find that address. Please check it.',
    );
  }
}
