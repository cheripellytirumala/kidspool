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

  static const Duration _maxFixAge = Duration(minutes: 2);
  static const Duration _fixTimeout = Duration(seconds: 3);

  @override
  Future<RideFix?> currentFix() async {
    try {
      if (!await _ensurePermission()) return null;
      // Ride actions (Start ride, Picked up, …) must not wait long for GPS:
      // a recent last-known fix is good enough, otherwise try briefly.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null &&
          DateTime.now().difference(last.timestamp) < _maxFixAge) {
        return _toFix(last);
      }
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: _fixTimeout,
          ),
        );
        return _toFix(position);
      } catch (_) {
        return last == null ? null : _toFix(last);
      }
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
