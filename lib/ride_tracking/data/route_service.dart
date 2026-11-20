import 'package:dio/dio.dart';

import '../../common/core/config/maps_config.dart';
import '../../common/core/services/maps_availability.dart';
import '../../common/core/utils/logger.dart';
import '../domain/entities/ride_tracking.dart';

/// Road routes for the ride map: the best route first, then alternatives.
///
/// Tries Google first — Routes API (`computeRoutes`), then the Directions
/// API — and, when Google refuses both (API not enabled / key restricted /
/// no key), the OpenStreetMap router (OSRM). A Google API that refused once
/// is skipped for the rest of the session. Never throws: an empty list only
/// when every router fails (the map then draws a straight line).
class RouteService {
  RouteService(this._dio, {Future<String?> Function()? nativeKey})
    : _nativeKey = nativeKey ?? MapsAvailability.nativeApiKey;

  final Dio _dio;
  final Future<String?> Function() _nativeKey;
  String? _key;

  /// Google refused these for this key (403 / REQUEST_DENIED): don't ask
  /// again on every refresh.
  bool _routesRefused = false;
  bool _directionsRefused = false;

  static const String _url =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  /// Routes from [from] to [to] through [via]. The first entry is the best
  /// full route; the rest are alternatives.
  ///
  /// The Routes API refuses alternatives when there are stops in between,
  /// so with [via] each leg (car → home, home → school) is asked for on its
  /// own: the best legs are joined into the main route and every leg's
  /// alternatives are returned after it.
  Future<List<List<GeoPoint>>> routes({
    required GeoPoint from,
    required GeoPoint to,
    List<GeoPoint> via = const [],
  }) async {
    final key = _key ??= MapsConfig.apiKey.isNotEmpty
        ? MapsConfig.apiKey
        : (await _nativeKey() ?? '');
    if (key.isEmpty && !useOsrmFallback) return const [];
    final stops = [from, ...via, to];
    final legs = await Future.wait([
      for (var i = 0; i < stops.length - 1; i++)
        _leg(key, stops[i], stops[i + 1]),
    ]);
    if (legs.any((l) => l.isEmpty)) return const [];
    final main = <GeoPoint>[
      for (final (i, leg) in legs.indexed)
        ...(i == 0 ? leg.first : leg.first.skip(1)),
    ];
    return [main, for (final leg in legs) ...leg.skip(1)];
  }

  /// One leg with alternatives; best route first. Empty on any failure.
  Future<List<List<GeoPoint>>> _leg(
    String key,
    GeoPoint from,
    GeoPoint to,
  ) async {
    Map<String, dynamic> point(GeoPoint p) => {
      'location': {
        'latLng': {'latitude': p.latitude, 'longitude': p.longitude},
      },
    };
    if (key.isEmpty || _routesRefused) return _directionsOrOsrm(key, from, to);
    try {
      final res = await _dio.post<dynamic>(
        _url,
        data: {
          'origin': point(from),
          'destination': point(to),
          'travelMode': 'DRIVE',
          'routingPreference': 'TRAFFIC_AWARE',
          'computeAlternativeRoutes': true,
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
      final routes = list is! List
          ? const <List<GeoPoint>>[]
          : [
              for (final r in list)
                if (r is Map &&
                    r['polyline'] is Map &&
                    (r['polyline'] as Map)['encodedPolyline'] is String)
                  decode((r['polyline'] as Map)['encodedPolyline'] as String),
            ].where((p) => p.length > 1).toList();
      if (routes.isNotEmpty) return routes;
    } on DioException catch (e) {
      // 403 = Routes API not enabled / key not allowed: stop asking.
      if (e.response?.statusCode == 403) _routesRefused = true;
      AppLogger.warning(
        'Routes API failed: ${e.response?.statusCode ?? e.type}',
        tag: 'RouteService',
      );
    } catch (e) {
      AppLogger.warning('Routes API failed: $e', tag: 'RouteService');
    }
    return _directionsOrOsrm(key, from, to);
  }

  /// Directions API, then the OpenStreetMap router.
  Future<List<List<GeoPoint>>> _directionsOrOsrm(
    String key,
    GeoPoint from,
    GeoPoint to,
  ) async {
    if (key.isNotEmpty && !_directionsRefused) {
      final directions = await _directionsLeg(key, from, to);
      if (directions.isNotEmpty) return directions;
    }
    if (!useOsrmFallback) return const [];
    return _osrmLeg(from, to);
  }

  /// On in every build; `--dart-define=OSRM_FALLBACK=false` turns it off.
  /// Note: router.project-osrm.org is a shared demo server (fair-use
  /// policy, no SLA) that receives the trip's coordinates.
  static const bool useOsrmFallback = bool.fromEnvironment(
    'OSRM_FALLBACK',
    defaultValue: true,
  );

  static const String _osrmUrl =
      'https://router.project-osrm.org/route/v1/driving';

  /// Same leg from the OpenStreetMap router, with alternatives. Empty on
  /// failure.
  Future<List<List<GeoPoint>>> _osrmLeg(GeoPoint from, GeoPoint to) async {
    try {
      final res = await _dio.get<dynamic>(
        '$_osrmUrl/${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}',
        queryParameters: {
          'alternatives': 'true',
          'overview': 'full',
          'geometries': 'polyline',
        },
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final data = res.data;
      if (data is! Map || data['code'] != 'Ok' || data['routes'] is! List) {
        return const [];
      }
      return [
        for (final r in data['routes'] as List)
          if (r is Map && r['geometry'] is String)
            decode(r['geometry'] as String),
      ].where((p) => p.length > 1).toList();
    } catch (e) {
      AppLogger.warning('OSRM fallback failed: $e', tag: 'RouteService');
      return const [];
    }
  }

  static const String _directionsUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Same leg through the (older) Directions API, with alternatives, for
  /// keys that have Directions enabled but not Routes. Empty on failure:
  /// the map then draws a straight line.
  Future<List<List<GeoPoint>>> _directionsLeg(
    String key,
    GeoPoint from,
    GeoPoint to,
  ) async {
    try {
      final res = await _dio.get<dynamic>(
        _directionsUrl,
        queryParameters: {
          'origin': '${from.latitude},${from.longitude}',
          'destination': '${to.latitude},${to.longitude}',
          'mode': 'driving',
          'alternatives': 'true',
          'key': key,
        },
      );
      final data = res.data;
      if (data is! Map || data['status'] != 'OK') {
        if (data is Map && data['status'] == 'REQUEST_DENIED') {
          _directionsRefused = true;
        }
        AppLogger.warning(
          'Directions API: ${data is Map ? data['status'] : 'no data'}',
          tag: 'RouteService',
        );
        return const [];
      }
      final list = data['routes'];
      if (list is! List) return const [];
      return [
        for (final r in list)
          if (r is Map &&
              r['overview_polyline'] is Map &&
              (r['overview_polyline'] as Map)['points'] is String)
            decode((r['overview_polyline'] as Map)['points'] as String),
      ].where((p) => p.length > 1).toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) _directionsRefused = true;
      AppLogger.warning(
        'Directions API failed: ${e.response?.statusCode ?? e.type}',
        tag: 'RouteService',
      );
      return const [];
    } catch (e) {
      AppLogger.warning('Directions API failed: $e', tag: 'RouteService');
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
