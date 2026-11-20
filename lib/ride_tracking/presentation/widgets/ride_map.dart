import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../common/core/services/maps_availability.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../core/constants/ride_map_style.dart';
import '../../core/constants/ride_tracking_assets.dart';
import '../../domain/entities/ride_tracking.dart' as ride;
import 'ride_map_markers.dart';
import 'ride_styles.dart';
import '../../../common/core/di/injection_container.dart';
import '../../data/route_service.dart';

/// Full-bleed map behind F22: driven route, the way still to go, every
/// alternative road route, the car, home and school markers and the school
/// zone, on the normal Google map, and glides the car along the road
/// between location fixes.
///
/// Only creates a [GoogleMap] when [MapsAvailability] says the native SDK
/// has a key (the iOS SDK crashes without one, and widget tests have no
/// native side); otherwise shows the design's static dark map artwork.
class RideMap extends StatefulWidget {
  const RideMap({
    super.key,
    required this.tracking,
    required this.padding,
    this.fallback,
  });

  final ride.RideTracking? tracking;

  /// Shown instead of [RideStaticMap] when no native map can be created.
  final Widget? fallback;

  /// Space covered by the header and the bottom sheet.
  final EdgeInsets padding;

  /// The nearest point to a GPS fix on a road route, and its distance in
  /// metres (see the map's road snapping).
  static (ride.GeoPoint, double) snapToRoute(
    ride.GeoPoint p,
    List<ride.GeoPoint> route,
  ) => _RideMapState.snapToRoute(p, route);

  @override
  State<RideMap> createState() => _RideMapState();
}

class _RideMapState extends State<RideMap> with SingleTickerProviderStateMixin {
  static const _fallbackCamera = CameraPosition(
    target: LatLng(37.7749, -122.4194),
    zoom: 13,
  );

  /// The school zone drawn on the map (geofence).
  static const double _zoneRadiusMeters = 120;

  bool? _mapAvailable;
  GoogleMapController? _controller;
  RideMapMarkers? _markers;
  String? _markersFor;
  DateTime? _lastTouch;
  bool _fitted = false;

  /// Road routes for the trip still ahead: best first, then alternatives.
  List<List<ride.GeoPoint>> _routes = const [];
  String? _routeKey;
  DateTime? _routeFetchedAt;
  bool _routeLoading = false;

  /// The car as drawn: glides from [_carPath]'s start to its end.
  late final AnimationController _carAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..addListener(_onCarTick);
  List<ride.GeoPoint> _carPath = const [];
  List<double> _carPathCum = const [];
  ride.GeoPoint? _carTarget;
  ride.GeoPoint? _carShown;

  /// Jumps instead of gliding past this (first fix, GPS teleport).
  static const double _maxGlideMeters = 2000;

  @override
  void initState() {
    super.initState();
    _carTarget = _carShown = widget.tracking?.location?.point;
    MapsAvailability.isNativeMapConfigured().then((ok) {
      if (!mounted) return;
      setState(() => _mapAvailable = ok);
      _maybeFetchRoute();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadMarkers();
    _maybeFetchRoute();
  }

  @override
  void didUpdateWidget(RideMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadMarkers();
    _maybeFetchRoute();
    _moveCar();
    _followCar();
  }

  /// Starts gliding the car to its newest fix, along the road route when
  /// both ends lie on it.
  void _moveCar() {
    final to = widget.tracking?.location?.point;
    if (to == _carTarget) return;
    _carTarget = to;
    final from = _carShown;
    if (to == null || from == null || from.metersTo(to) > _maxGlideMeters) {
      _carAnim.stop();
      _carShown = to; // didUpdateWidget is followed by build.
      return;
    }
    final path = _roadBetween(from, to);
    final cum = <double>[0];
    for (var i = 1; i < path.length; i++) {
      cum.add(cum.last + path[i - 1].metersTo(path[i]));
    }
    _carPath = path;
    _carPathCum = cum;
    _carAnim.forward(from: 0);
  }

  /// [from] → [to] following the active route's points between them, or a
  /// straight hop when either end is off the route.
  List<ride.GeoPoint> _roadBetween(ride.GeoPoint from, ride.GeoPoint to) {
    if (_routes.isEmpty) return [from, to];
    final route = _routes[_activeRouteIndex(from)];
    final (i, di) = _nearestIndex(from, route);
    final (j, dj) = _nearestIndex(to, route);
    if (di > 50 || dj > 50 || j <= i) return [from, to];
    return [from, ...route.sublist(i + 1, j + 1), to];
  }

  /// GPS is off by 5–30 m in town: within [_snapMeters] of the route being
  /// driven, the car is drawn on the road (like a navigation app).
  static const double _snapMeters = 35;

  ride.GeoPoint? get _carOnRoad {
    final car = _carShown;
    if (car == null || _routes.isEmpty) return car;
    final snapped = snapToRoute(car, _routes[_activeRouteIndex(car)]);
    return snapped.$2 <= _snapMeters ? snapped.$1 : car;
  }

  /// The nearest point to [p] on [route] (projected onto its segments) and
  /// how far away it is, in metres.
  static (ride.GeoPoint, double) snapToRoute(
    ride.GeoPoint p,
    List<ride.GeoPoint> route,
  ) {
    if (route.isEmpty) return (p, double.infinity);
    if (route.length == 1) return (route.first, p.metersTo(route.first));
    // Local flat projection around p: metres east / north.
    const mPerDegLat = 111320.0;
    final mPerDegLng = mPerDegLat * math.cos(p.latitude * math.pi / 180);
    (double, double) xy(ride.GeoPoint q) => (
      (q.longitude - p.longitude) * mPerDegLng,
      (q.latitude - p.latitude) * mPerDegLat,
    );
    var best = route.first;
    var bestD = double.infinity;
    for (var i = 0; i < route.length - 1; i++) {
      final (ax, ay) = xy(route[i]);
      final (bx, by) = xy(route[i + 1]);
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      final t = len2 == 0
          ? 0.0
          : ((-ax * dx - ay * dy) / len2).clamp(0.0, 1.0).toDouble();
      final cx = ax + dx * t, cy = ay + dy * t;
      final d = math.sqrt(cx * cx + cy * cy);
      if (d < bestD) {
        bestD = d;
        best = ride.GeoPoint(
          p.latitude + cy / mPerDegLat,
          p.longitude + (mPerDegLng == 0 ? 0 : cx / mPerDegLng),
        );
      }
    }
    return (best, bestD);
  }

  void _onCarTick() {
    final path = _carPath;
    if (path.length < 2) return;
    final total = _carPathCum.last;
    final t = Curves.easeInOut.transform(_carAnim.value);
    if (total <= 0 || t >= 1) {
      setState(() => _carShown = path.last);
      return;
    }
    final d = total * t;
    var k = 1;
    while (k < path.length - 1 && _carPathCum[k] < d) {
      k++;
    }
    final a = path[k - 1], b = path[k];
    final seg = _carPathCum[k] - _carPathCum[k - 1];
    final f = seg <= 0 ? 1.0 : (d - _carPathCum[k - 1]) / seg;
    setState(
      () => _carShown = ride.GeoPoint(
        a.latitude + (b.latitude - a.latitude) * f,
        a.longitude + (b.longitude - a.longitude) * f,
      ),
    );
  }

  /// Fetches the road route again when the leg changes (picked up), when
  /// there is none yet (at most once a minute), or when the car has left
  /// it by more than 150 m (at most every 30 s).
  void _maybeFetchRoute() {
    final t = widget.tracking;
    if (_mapAvailable != true || !sl.isRegistered<RouteService>()) return;
    if (t == null || t.completed || _routeLoading) return;
    final to = t.destination.point;
    final car = t.location?.point;
    final from = car ?? t.pickup.point;
    if (to == null || from == null) return;
    final via = [if (!t.pickedUp && car != null) ?t.pickup.point];
    final key = '${t.pickedUp}|${to.latitude},${to.longitude}';
    final since = _routeFetchedAt == null
        ? const Duration(days: 1)
        : DateTime.now().difference(_routeFetchedAt!);
    final offRoute =
        car != null &&
        _routes.isNotEmpty &&
        _routes.every((r) => _distanceToRoute(car, r) > 150);
    final due =
        key != _routeKey ||
        (_routes.isEmpty && since > const Duration(minutes: 1)) ||
        (offRoute && since > const Duration(seconds: 30));
    if (!due) return;
    _routeKey = key;
    _routeFetchedAt = DateTime.now();
    _routeLoading = true;
    sl<RouteService>().routes(from: from, to: to, via: via).then((r) {
      _routeLoading = false;
      if (mounted) setState(() => _routes = r);
    });
  }

  static double _distanceToRoute(ride.GeoPoint p, List<ride.GeoPoint> route) =>
      _nearestIndex(p, route).$2;

  static (int, double) _nearestIndex(
    ride.GeoPoint p,
    List<ride.GeoPoint> route,
  ) {
    var nearest = 0;
    var best = double.infinity;
    for (final (i, q) in route.indexed) {
      final d = p.metersTo(q);
      if (d < best) {
        best = d;
        nearest = i;
      }
    }
    return (nearest, best);
  }

  /// The route the car is driving on: the main one unless it's clearly on
  /// an alternative (within 50 m of it and further from the main one).
  int _activeRouteIndex(ride.GeoPoint? car) {
    if (car == null || _routes.length < 2) return 0;
    var index = 0;
    var best = _distanceToRoute(car, _routes.first);
    if (best <= 50) return 0;
    for (var i = 1; i < _routes.length; i++) {
      final d = _distanceToRoute(car, _routes[i]);
      if (d <= 50 && d < best) {
        best = d;
        index = i;
      }
    }
    return index;
  }

  /// The main route from the point nearest the car onwards, so the part
  /// already driven isn't drawn as "ahead".
  static List<ride.GeoPoint> _aheadOf(
    ride.GeoPoint? car,
    List<ride.GeoPoint> route,
  ) {
    if (car == null || route.length < 2) return route;
    final (nearest, _) = _nearestIndex(car, route);
    return [car, ...route.sublist(nearest)];
  }

  @override
  void dispose() {
    _carAnim.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _loadMarkers() {
    if (_mapAvailable == false) return;
    final label = widget.tracking?.destination.label ?? '';
    if (_markersFor == label) return;
    _markersFor = label;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    RideMapMarkers.load(pixelRatio: ratio, schoolLabel: label).then((m) {
      if (mounted) setState(() => _markers = m);
    }, onError: (_) {});
  }

  static LatLng _ll(ride.GeoPoint p) => LatLng(p.latitude, p.longitude);

  List<LatLng> get _focusPoints {
    final t = widget.tracking;
    if (t == null) return const [];
    return [
      ?(_carShown ?? t.location?.point),
      if (!t.pickedUp) ?t.pickup.point,
      ?t.destination.point,
    ].map(_ll).toList();
  }

  /// Keeps the car and its next stop in view unless the user just moved the
  /// map around.
  void _followCar({bool force = false}) {
    final controller = _controller;
    final points = _focusPoints;
    if (controller == null || points.isEmpty) return;
    final touched = _lastTouch;
    if (!force &&
        _fitted &&
        touched != null &&
        DateTime.now().difference(touched) < const Duration(seconds: 20)) {
      return;
    }
    _fitted = true;
    final CameraUpdate update;
    if (points.length == 1) {
      update = CameraUpdate.newLatLngZoom(points.first, 15);
    } else {
      var south = points.first.latitude, north = south;
      var west = points.first.longitude, east = west;
      for (final p in points) {
        south = math.min(south, p.latitude);
        north = math.max(north, p.latitude);
        west = math.min(west, p.longitude);
        east = math.max(east, p.longitude);
      }
      update = CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        48,
      );
    }
    unawaited(controller.animateCamera(update).catchError((Object _) {}));
  }

  /// Opens already framing every stop. Starting zoomed in on one end of a
  /// very long route made the iOS Maps SDK lay out the whole route at street
  /// zoom and freeze the app.
  CameraPosition get _initialCamera {
    final points = _focusPoints;
    if (points.isEmpty) return _fallbackCamera;
    if (points.length == 1) {
      return CameraPosition(target: points.first, zoom: 14);
    }
    var south = points.first.latitude, north = south;
    var west = points.first.longitude, east = west;
    for (final p in points) {
      south = math.min(south, p.latitude);
      north = math.max(north, p.latitude);
      west = math.min(west, p.longitude);
      east = math.max(east, p.longitude);
    }
    final span = math.max(north - south, (east - west).abs());
    // ~360° fills the world at zoom 0; leave room for the header and sheet.
    final zoom = span <= 0
        ? 14.0
        : (math.log(360 / span) / math.ln2 - 1.5).clamp(1.0, 15.0).toDouble();
    return CameraPosition(
      target: LatLng((south + north) / 2, (west + east) / 2),
      zoom: zoom,
    );
  }

  /// Dotted patterns are laid out dot by dot by the SDK; keep them for
  /// normal trips only.
  static const double _maxDottedMeters = 50000;

  static double _lengthMeters(List<ride.GeoPoint> points) {
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += points[i].metersTo(points[i + 1]);
    }
    return total;
  }

  Set<Marker> _buildMarkers() {
    final t = widget.tracking;
    final m = _markers;
    if (t == null || m == null) return const {};
    return {
      if (t.pickup.point case final p?)
        Marker(
          markerId: const MarkerId('home'),
          position: _ll(p),
          icon: m.home,
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(title: t.pickup.label),
        ),
      if (t.destination.point case final p?)
        Marker(
          markerId: const MarkerId('school'),
          position: _ll(p),
          icon: m.school,
          // Pin tip sits at the bottom of the 34px icon (y = 51 of 60).
          anchor: const Offset(0.5, 51 / 60),
        ),
      if (_carOnRoad case final p?)
        Marker(
          markerId: const MarkerId('car'),
          position: _ll(p),
          icon: m.car,
          anchor: const Offset(0.5, 30 / 64),
          zIndexInt: 2,
        ),
    };
  }

  /// The normal Google map (streets, labels) before, during and after the
  /// ride: the black style is no longer used on the live map.
  bool get _dark => false;

  Set<Polyline> _buildPolylines() {
    final t = widget.tracking;
    if (t == null) return const {};
    final dark = _dark;
    final car = _carOnRoad;
    final driven = [...t.path, ?car];
    final lines = <Polyline>{
      // Where the car has been: a solid trail (dimmed lime on the black map).
      if (driven.length > 1)
        Polyline(
          polylineId: const PolylineId('driven'),
          points: driven.map(_ll).toList(),
          color: dark ? AppColors.lime.withValues(alpha: 0.55) : AppColors.ink,
          width: 5,
          zIndex: 3,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
    };
    if (t.completed) return lines;

    if (_routes.isNotEmpty) {
      final active = _activeRouteIndex(car);
      // Every other way to get there, in grey under the one being driven.
      for (final (i, alt) in _routes.indexed) {
        if (i == active) continue;
        lines.add(
          Polyline(
            polylineId: PolylineId('alt$i'),
            points: alt.map(_ll).toList(),
            color: dark
                ? RideColors.routeAlternative.withValues(alpha: 0.6)
                : RideColors.routeAlternative,
            width: 5,
            zIndex: 0,
            jointType: JointType.round,
          ),
        );
      }
      final ahead = _aheadOf(car, _routes[active]).map(_ll).toList();
      lines
        ..add(
          Polyline(
            polylineId: const PolylineId('ahead-outline'),
            points: ahead,
            color: dark
                ? AppColors.lime.withValues(alpha: 0.25)
                : AppColors.ink,
            width: dark ? 12 : 9,
            zIndex: 1,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        )
        ..add(
          Polyline(
            polylineId: const PolylineId('ahead'),
            points: ahead,
            color: AppColors.lime,
            width: 6,
            zIndex: 2,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      return lines;
    }

    // No road route (Routes API off / offline): a straight line from the
    // car (or, before its first fix, the pickup) to the school, drawn like
    // the route so it is always visible.
    final ahead = [
      car ?? t.pickup.point,
      if (!t.pickedUp && car != null) ?t.pickup.point,
      ?t.destination.point,
    ].nonNulls.toList();
    if (ahead.length > 1) {
      final points = ahead.map(_ll).toList();
      final dotted = _lengthMeters(ahead) <= _maxDottedMeters;
      lines
        ..add(
          Polyline(
            polylineId: const PolylineId('ahead-outline'),
            points: points,
            color: AppColors.ink,
            width: 9,
            zIndex: 1,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        )
        ..add(
          Polyline(
            polylineId: const PolylineId('ahead'),
            points: points,
            color: AppColors.lime,
            width: 6,
            zIndex: 2,
            jointType: JointType.round,
            patterns: dotted
                ? [PatternItem.dash(18), PatternItem.gap(10)]
                : const [],
          ),
        );
    }
    return lines;
  }

  Set<Circle> _buildCircles() {
    final school = widget.tracking?.destination.point;
    if (school == null) return const {};
    return {
      Circle(
        circleId: const CircleId('school-zone'),
        center: _ll(school),
        radius: _zoneRadiusMeters,
        fillColor: AppColors.lime.withValues(alpha: 0.12),
        strokeColor: AppColors.lime,
        strokeWidth: 2,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_mapAvailable != true) {
      return widget.fallback ??
          RideStaticMap(schoolLabel: widget.tracking?.destination.label);
    }
    return Listener(
      onPointerDown: (_) => _lastTouch = DateTime.now(),
      child: GoogleMap(
        initialCameraPosition: _initialCamera,
        // The normal Google map; '[]' (not null) resets any earlier style.
        style: _dark ? RideMapStyle.dark : '[]',
        onMapCreated: (c) {
          _controller = c;
          _followCar(force: true);
        },
        markers: _buildMarkers(),
        polylines: _buildPolylines(),
        circles: _buildCircles(),
        padding: widget.padding,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: false,
        buildingsEnabled: true,
        trafficEnabled: false,
      ),
    );
  }
}

/// The Figma "Map/Dark" artwork with the design's route, school zone and
/// car marker, shown when no native map can be created.
class RideStaticMap extends StatelessWidget {
  const RideStaticMap({super.key, this.schoolLabel});

  final String? schoolLabel;

  // Figma frame (F22 · Live tracking).
  static const double _w = 390;
  static const double _h = 844;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.inverse,
      child: LayoutBuilder(
        builder: (context, box) {
          final sx = box.maxWidth / _w;
          final sy = box.maxHeight / _h;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: -200 * sx,
                top: -40 * sy,
                width: 800 * sx,
                height: 900 * sy,
                child: SvgPicture.asset(
                  RideTrackingAssets.mapDark,
                  fit: BoxFit.fill,
                ),
              ),
              Positioned.fill(
                child: CustomPaint(painter: _StaticRoutePainter(sx, sy)),
              ),
              Positioned(
                left: 233 * sx,
                top: 244 * sy,
                width: 140 * sx,
                child: _StaticSchoolPin(label: schoolLabel),
              ),
              Positioned(
                left: 156 * sx,
                top: 376 * sy,
                child: const RideCarMarker(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StaticSchoolPin extends StatelessWidget {
  const _StaticSchoolPin({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 16,
          child: Text(
            label ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: RideTextStyles.labelS.copyWith(color: AppColors.lime),
          ),
        ),
        const SizedBox(height: 4 + 2.83),
        SvgPicture.asset(
          RideTrackingAssets.schoolPin,
          width: 19.8333,
          height: 28.3333,
        ),
      ],
    );
  }
}

/// Figma "Car marker": 48px lime disc, 4px ink ring, Glow/Lime, car 22px.
class RideCarMarker extends StatelessWidget {
  const RideCarMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.lime,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.inverse, width: 4),
        boxShadow: const [
          BoxShadow(
            color: AppColors.limeGlow,
            offset: Offset(0, 8),
            blurRadius: 12,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        RideTrackingAssets.car,
        width: 18.33,
        height: 13.4,
        fit: BoxFit.fill,
      ),
    );
  }
}

class _StaticRoutePainter extends CustomPainter {
  _StaticRoutePainter(this.sx, this.sy);

  final double sx;
  final double sy;

  Offset _p(double x, double y) => Offset(x * sx, y * sy);

  @override
  void paint(Canvas canvas, Size size) {
    // School zone (Geofence · School zone, 150px at 228,228).
    final center = _p(303, 303);
    final radius = 75 * math.min(sx, sy).toDouble();
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = AppColors.lime.withValues(alpha: 0.12),
    );
    final ring = Paint()
      ..color = AppColors.lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dashes = 36;
    for (var i = 0; i < dashes; i++) {
      final start = i * 2 * math.pi / dashes;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        math.pi / dashes,
        false,
        ring,
      );
    }

    // Driven route (lime) to the car.
    final driven = Path()
      ..moveTo(_p(68, 298).dx, _p(68, 298).dy)
      ..lineTo(_p(68, 386).dx, _p(68, 386).dy)
      ..quadraticBezierTo(
        _p(68, 400).dx,
        _p(68, 400).dy,
        _p(82, 400).dx,
        _p(82, 400).dy,
      )
      ..lineTo(_p(170, 400).dx, _p(170, 400).dy);
    canvas.drawPath(
      driven,
      Paint()
        ..color = AppColors.lime
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // Still to go (dotted) from the car up to the school.
    final dot = Paint()..color = RideColors.routeAhead;
    final ahead = [_p(206, 398), _p(236, 392), _p(241, 375), _p(241, 212)];
    for (var i = 0; i < ahead.length - 1; i++) {
      final a = ahead[i];
      final b = ahead[i + 1];
      final length = (b - a).distance;
      for (var d = 0.0; d <= length; d += 9) {
        canvas.drawCircle(Offset.lerp(a, b, d / length)!, 1.8, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_StaticRoutePainter old) => old.sx != sx || old.sy != sy;
}
