import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../core/constants/ride_tracking_assets.dart';

/// Marker bitmaps drawn from the Figma pieces: the lime "Car marker", the
/// "Pin · {school}" with its label, and a small home stop.
class RideMapMarkers {
  const RideMapMarkers({
    required this.car,
    required this.school,
    required this.home,
  });

  final BitmapDescriptor car;
  final BitmapDescriptor school;
  final BitmapDescriptor home;

  static Future<RideMapMarkers> load({
    required double pixelRatio,
    required String schoolLabel,
  }) async {
    final carIcon = await _picture(RideTrackingAssets.car);
    final pinIcon = await _picture(RideTrackingAssets.schoolPin);
    final homeIcon = await _picture(RideTrackingAssets.home);
    try {
      return RideMapMarkers(
        car: await _render(const Size(64, 64), pixelRatio, (c) {
          // 48px lime disc, 4px ink ring, Glow/Lime; car icon 22px.
          const center = Offset(32, 30);
          c.drawCircle(
            center + const Offset(0, 8),
            24,
            Paint()
              ..color = AppColors.limeGlow
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          );
          c.drawCircle(center, 24, Paint()..color = AppColors.ink);
          c.drawCircle(center, 20, Paint()..color = AppColors.lime);
          _drawPicture(c, carIcon, const Rect.fromLTWH(22.8, 22.9, 18.4, 14.2));
        }),
        school: await _render(const Size(140, 60), pixelRatio, (c) {
          final label = TextPainter(
            text: TextSpan(
              text: schoolLabel,
              style: const TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 12,
                height: 16 / 12,
                fontWeight: FontWeight.w500,
                color: AppColors.lime,
              ),
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            maxLines: 1,
            ellipsis: '…',
          )..layout(maxWidth: 140);
          label.paint(c, Offset((140 - label.width) / 2, 0));
          // Icon/pin 34px; the glyph fills 8.33% / 20.83% insets.
          _drawPicture(
            c,
            pinIcon,
            const Rect.fromLTWH(60.08, 22.83, 19.83, 28.33),
          );
        }),
        home: await _render(const Size(36, 36), pixelRatio, (c) {
          const center = Offset(18, 18);
          c.drawCircle(center, 16, Paint()..color = AppColors.ink);
          c.drawCircle(center, 14, Paint()..color = AppColors.screen);
          _drawPicture(c, homeIcon, const Rect.fromLTWH(10, 10, 16, 16));
        }),
      );
    } finally {
      carIcon.picture.dispose();
      pinIcon.picture.dispose();
      homeIcon.picture.dispose();
    }
  }

  static Future<PictureInfo> _picture(String asset) =>
      vg.loadPicture(SvgAssetLoader(asset), null);

  static void _drawPicture(Canvas canvas, PictureInfo info, Rect rect) {
    canvas
      ..save()
      ..translate(rect.left, rect.top)
      ..scale(rect.width / info.size.width, rect.height / info.size.height)
      ..drawPicture(info.picture)
      ..restore();
  }

  static Future<BitmapDescriptor> _render(
    Size size,
    double pixelRatio,
    void Function(Canvas canvas) paint,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    paint(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size.width * pixelRatio).ceil(),
      (size.height * pixelRatio).ceil(),
    );
    picture.dispose();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
    );
  }
}
