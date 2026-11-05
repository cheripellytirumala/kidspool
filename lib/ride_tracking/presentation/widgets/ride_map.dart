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

/// Full-bleed dark map behind F22: driven route (lime), the way still to go
/// (dotted), the car, home and school markers and the school zone.
///
/// Only creates a [GoogleMap] when [MapsAvailability] says the native SDK
/// has a key (the iOS SDK crashes without one, and widget tests have no
/// native side); otherwise shows the design's static dark map artwork.
class RideMap extends StatefulWidget {
  const RideMap({super.key, required this.tracking, required this.padding});

  final ride.RideTracking? tracking;

  /// Space covered by the header and the bottom sheet.
  final EdgeInsets padding;

  @override
  State<RideMap> createState() => _RideMapState();
}

class _RideMapState extends State<RideMap> {
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

  @override
  void initState() {
    super.initState();
    MapsAvailability.isNativeMapConfigured().then((ok) {
      if (mounted) setState(() => _mapAvailable = ok);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadMarkers();
  }

  @override
  void didUpdateWidget(RideMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadMarkers();
    _followCar();
  }

  @override
  void dispose() {
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
      ?t.location?.point,
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
      if (t.location?.point case final p?)
        Marker(
          markerId: const MarkerId('car'),
          position: _ll(p),
          icon: m.car,
          anchor: const Offset(0.5, 30 / 64),
          zIndexInt: 2,
        ),
    };
  }

  Set<Polyline> _buildPolylines() {
    final t = widget.tracking;
    if (t == null) return const {};
    final car = t.location?.point;
    final driven = [...t.path, ?car];
    final ahead = [
      ?car,
      if (!t.pickedUp) ?t.pickup.point,
      ?t.destination.point,
    ];
    return {
      if (driven.length > 1)
        Polyline(
          polylineId: const PolylineId('driven'),
          points: driven.map(_ll).toList(),
          color: AppColors.lime,
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      if (ahead.length > 1)
        Polyline(
          polylineId: const PolylineId('ahead'),
          points: ahead.map(_ll).toList(),
          color: RideColors.routeAhead,
          width: 4,
          patterns: _lengthMeters(ahead) <= _maxDottedMeters
              ? [PatternItem.dot, PatternItem.gap(10)]
              : const [],
        ),
    };
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
      return RideStaticMap(schoolLabel: widget.tracking?.destination.label);
    }
    return Listener(
      onPointerDown: (_) => _lastTouch = DateTime.now(),
      child: GoogleMap(
        initialCameraPosition: _initialCamera,
        style: RideMapStyle.dark,
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
        buildingsEnabled: false,
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
