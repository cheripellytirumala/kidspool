import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/ride_tracking/data/route_service.dart';
import 'package:kidspool/ride_tracking/domain/entities/ride_tracking.dart';

/// Answers each host with a canned response and counts the calls.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.reply);

  final ResponseBody Function(RequestOptions o) reply;
  final List<String> hosts = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    hosts.add(options.uri.host);
    return reply(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, [int status = 200]) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

// "_p~iF~ps|U_ulLnnqC_mqNvxq`@" = (38.5,-120.2) (40.7,-120.95) (43.252,-126.453)
const _poly = r'_p~iF~ps|U_ulLnnqC_mqNvxq`@';

void main() {
  const from = GeoPoint(38.5, -120.2);
  const to = GeoPoint(43.252, -126.453);

  RouteService service(_FakeAdapter a, {String key = 'k'}) =>
      RouteService(Dio()..httpClientAdapter = a, nativeKey: () async => key);

  test('uses the Routes API when Google answers', () async {
    final a = _FakeAdapter(
      (_) => _json('{"routes":[{"polyline":{"encodedPolyline":"$_poly"}}]}'),
    );
    final r = await service(a).routes(from: from, to: to);
    expect(r, hasLength(1));
    expect(r.first, hasLength(3));
    expect(a.hosts, ['routes.googleapis.com']);
  });

  test('Routes refused → Directions API', () async {
    final a = _FakeAdapter(
      (o) => o.uri.host == 'routes.googleapis.com'
          ? _json('{"error":{"status":"PERMISSION_DENIED"}}', 403)
          : _json(
              '{"status":"OK","routes":[{"overview_polyline":{"points":"$_poly"}}]}',
            ),
    );
    final r = await service(a).routes(from: from, to: to);
    expect(r.single, hasLength(3));
    expect(a.hosts, ['routes.googleapis.com', 'maps.googleapis.com']);
  });

  test(
    'both Google APIs refused → OpenStreetMap, Google skipped after',
    () async {
      final a = _FakeAdapter((o) {
        if (o.uri.host == 'routes.googleapis.com') {
          return _json('{"error":{}}', 403);
        }
        if (o.uri.host == 'maps.googleapis.com') {
          return _json('{"status":"REQUEST_DENIED","routes":[]}');
        }
        return _json(
          '{"code":"Ok","routes":[{"geometry":"$_poly"},{"geometry":"$_poly"}]}',
        );
      });
      final s = service(a);
      final r = await s.routes(from: from, to: to);
      expect(r, hasLength(2));
      expect(a.hosts.last, 'router.project-osrm.org');

      a.hosts.clear();
      await s.routes(from: from, to: to);
      expect(a.hosts, ['router.project-osrm.org']);
    },
  );

  test('no Google key → straight to OpenStreetMap', () async {
    final a = _FakeAdapter(
      (_) => _json('{"code":"Ok","routes":[{"geometry":"$_poly"}]}'),
    );
    final r = await service(a, key: '').routes(from: from, to: to);
    expect(r.single, hasLength(3));
    expect(a.hosts, ['router.project-osrm.org']);
  });

  test('legs through a stop are joined', () async {
    final a = _FakeAdapter(
      (_) => _json('{"code":"Ok","routes":[{"geometry":"$_poly"}]}'),
    );
    final r = await service(
      a,
      key: '',
    ).routes(from: from, to: to, via: const [GeoPoint(40, -121)]);
    // 3 + 3 points, the shared joint counted once.
    expect(r.single, hasLength(5));
  });

  test('every router fails → empty (straight line)', () async {
    final a = _FakeAdapter((_) => _json('{}', 500));
    expect(await service(a).routes(from: from, to: to), isEmpty);
  });
}
