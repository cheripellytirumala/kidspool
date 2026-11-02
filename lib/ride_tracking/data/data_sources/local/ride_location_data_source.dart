import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../../../common/core/error/exceptions.dart';
import '../../../core/constants/ride_tracking_api_constants.dart';
import '../../models/ride_fix.dart';

/// The Ride Partner's phone GPS (geolocator).
abstract interface class RideLocationDataSource {
  /// Best-effort current fix: null when location is off, denied or slow.
  Future<RideFix?> currentFix();

  /// Live fixes while listened to. Emits a [DeviceException] error when
  /// location is unavailable.
  Stream<RideFix> fixes();
}

class RideLocationDataSourceImpl implements RideLocationDataSource {
  const RideLocationDataSourceImpl();

  @override
  Future<RideFix?> currentFix() async {
    try {
      if (!await _ensurePermission()) return null;
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }
      if (position == null) return null;
      return _toFix(position);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<RideFix> fixes() async* {
    if (!await _ensurePermission()) {
      throw const DeviceException(
        'Allow location access so the parent can follow the ride.',
      );
    }
    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: RideTrackingApiConstants.locationDistanceFilterMeters,
      ),
    ).map(_toFix);
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static RideFix _toFix(Position p) => RideFix(
    latitude: p.latitude,
    longitude: p.longitude,
    heading: p.heading,
    speed: p.speed,
    accuracy: p.accuracy,
  );
}
