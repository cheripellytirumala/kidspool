import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/ride_tracking/data/route_service.dart';
import 'package:kidspool/ride_tracking/domain/entities/ride_tracking.dart';

/// Answers each host with a canned response and records the call order.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  /// host → (status, body).
  final Map<String, (int, Object)> responses;
  final List<String> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final host = options.uri.host;
    calls.add(host);
    final (status, body) = responses[host] ?? (404, {});
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

// "_p~iF~ps|U_ulLnnqC_mqNvxq`@" is Google's documented sample polyline
// (3 points); "??_ibE_ibE" decodes to 2 points.
const _routesHost = 'routes.googleapis.com';
const _directionsHost = 'maps.googleapis.com';
const _osrmHost = 'router.project-osrm.org';

RouteService _service(_FakeAdapter adapter) => RouteService(
  Dio()..httpClientAdapter = adapter,
  nativeKey: () async => 'test-key',
);

const _from = GeoPoint(17.4558, 78.3652);
const _to = GeoPoint(17.44, 78.39);

void main() {
  test('fallback is on in debug/test builds', () {
    expect(RouteService.useOsrmFallback, isTrue);
  });

  test('Google Routes OK: uses it, no other calls', () async {
    final adapter = _FakeAdapter({
      _routesHost: (
        200,
        {
          'routes': [
            {
              'polyline': {'encodedPolyline': '_p~iF~ps|U_ulLnnqC_mqNvxq`@'},
            },
            {
              'polyline': {'encodedPolyline': '??_ibE_ibE'},
            },
          ],
        },
      ),
    });
    final routes = await _service(adapter).routes(from: _from, to: _to);
    expect(adapter.calls, [_routesHost]);
    expect(routes, hasLength(2));
    expect(routes.first, hasLength(3));
  });

  test('Routes refused → Directions OK: uses Directions', () async {
    final adapter = _FakeAdapter({
      _routesHost: (
        403,
        {
          'error': {'status': 'PERMISSION_DENIED'},
        },
      ),
      _directionsHost: (
        200,
        {
          'status': 'OK',
          'routes': [
            {
              'overview_polyline': {'points': '_p~iF~ps|U_ulLnnqC_mqNvxq`@'},
            },
          ],
        },
      ),
    });
    final routes = await _service(adapter).routes(from: _from, to: _to);
    expect(adapter.calls, [_routesHost, _directionsHost]);
    expect(routes, hasLength(1));
  });

  test('Routes and Directions refused → OpenStreetMap', () async {
    final adapter = _FakeAdapter({
      _routesHost: (
        403,
        {
          'error': {'status': 'PERMISSION_DENIED'},
        },
      ),
      _directionsHost: (200, {'status': 'REQUEST_DENIED', 'routes': []}),
      _osrmHost: (
        200,
        {
          'code': 'Ok',
          'routes': [
            {'geometry': '_p~iF~ps|U_ulLnnqC_mqNvxq`@'},
            {'geometry': '??_ibE_ibE'},
          ],
        },
      ),
    });
    final routes = await _service(adapter).routes(from: _from, to: _to);
    expect(adapter.calls, [_routesHost, _directionsHost, _osrmHost]);
    expect(routes, hasLength(2), reason: 'main route + 1 alternative');
    expect(routes.first.first.latitude, closeTo(38.5, 1e-5));
  });

  test('everything refused → empty (map draws the straight line)', () async {
    final adapter = _FakeAdapter({
      _routesHost: (403, {}),
      _directionsHost: (200, {'status': 'REQUEST_DENIED'}),
      _osrmHost: (500, {}),
    });
    final routes = await _service(adapter).routes(from: _from, to: _to);
    expect(adapter.calls, [_routesHost, _directionsHost, _osrmHost]);
    expect(routes, isEmpty);
  });

  test('stop on the way: each leg falls back on its own', () async {
    final adapter = _FakeAdapter({
      _routesHost: (403, {}),
      _directionsHost: (200, {'status': 'REQUEST_DENIED'}),
      _osrmHost: (
        200,
        {
          'code': 'Ok',
          'routes': [
            {'geometry': '_p~iF~ps|U_ulLnnqC_mqNvxq`@'},
          ],
        },
      ),
    });
    final routes = await _service(
      adapter,
    ).routes(from: _from, to: _to, via: const [GeoPoint(17.45, 78.37)]);
    expect(adapter.calls.where((h) => h == _osrmHost), hasLength(2));
    // Two 3-point legs joined (shared point counted once).
    expect(routes.first, hasLength(5));
  });
}
