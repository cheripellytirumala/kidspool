import 'package:dio/dio.dart';

import '../../common/core/config/maps_config.dart';
import '../../common/core/services/maps_availability.dart';
import '../../common/core/utils/logger.dart';
import '../domain/entities/ride_tracking.dart';

/// Road routes for the ride map (Google Routes API `computeRoutes`): the
/// best route first, then up to two alternatives. Never throws: an empty
/// list when routing isn't available (the map then draws a straight line).
class RouteService {
  RouteService(this._dio, {Future<String?> Function()? nativeKey})
    : _nativeKey = nativeKey ?? MapsAvailability.nativeApiKey;

  final Dio _dio;
  final Future<String?> Function() _nativeKey;
  String? _key;

  static const String _url =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  Future<List<List<GeoPoint>>> routes({
    required GeoPoint from,
    required GeoPoint to,
    List<GeoPoint> via = const [],
  }) async {
    final key = _key ??= MapsConfig.apiKey.isNotEmpty
        ? MapsConfig.apiKey
        : (await _nativeKey() ?? '');
    if (key.isEmpty) return const [];
    Map<String, dynamic> point(GeoPoint p) => {
      'location': {
        'latLng': {'latitude': p.latitude, 'longitude': p.longitude},
      },
    };
    try {
      final res = await _dio.post<dynamic>(
        _url,
        data: {
          'origin': point(from),
          'destination': point(to),
          if (via.isNotEmpty) 'intermediates': [for (final p in via) point(p)],
          'travelMode': 'DRIVE',
          'routingPreference': 'TRAFFIC_AWARE',
          // Alternatives aren't allowed with stops in between.
          'computeAlternativeRoutes': via.isEmpty,
        },
        options: Options(
          headers: {
            MapsConfig.headerApiKey: key,
            MapsConfig.headerFieldMask: 'routes.polyline.encodedPolyline',
          },
        ),
      );
      final data = res.data;
      final list = data is Map ? data['routes'] : null;
      if (list is! List) return const [];
      return [
        for (final r in list)
          if (r is Map &&
              r['polyline'] is Map &&
              (r['polyline'] as Map)['encodedPolyline'] is String)
            decode((r['polyline'] as Map)['encodedPolyline'] as String),
      ].where((p) => p.length > 1).toList();
    } catch (e) {
      // Routes API off or no network: the map falls back to straight lines.
      AppLogger.warning('Route request failed: $e', tag: 'RouteService');
      return const [];
    }
  }

  /// Google's encoded polyline format → points.
  static List<GeoPoint> decode(String encoded) {
    final points = <GeoPoint>[];
    var index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      for (var coord = 0; coord < 2; coord++) {
        var shift = 0, result = 0, b = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20 && index < encoded.length);
        final delta = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
        if (coord == 0) {
          lat += delta;
        } else {
          lng += delta;
        }
      }
      points.add(GeoPoint(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
