// Renders the kidpool app icon / splash PNGs from assets/icons/logo_glyph.svg.
//
// Regenerate with:
//   flutter test tool/generate_brand_images_test.dart
//   dart run flutter_launcher_icons && dart run flutter_native_splash:create
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _lime = Color(0xFFC7FF2E);

Future<void> _render(
  String path,
  int size, {
  required double glyphFraction,
  Color? background,
  double? markFraction, // draws the rounded lime mark (Figma: 104px, r36)
}) async {
  final svg = File('assets/icons/logo_glyph.svg').readAsStringSync();
  final info = await vg.loadPicture(SvgStringLoader(svg), null);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = size.toDouble();
  if (background != null) {
    canvas.drawRect(Rect.fromLTWH(0, 0, s, s), Paint()..color = background);
  }
  if (markFraction != null) {
    final m = s * markFraction;
    final rect = Rect.fromCenter(center: Offset(s / 2, s / 2), width: m, height: m);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(m * 36 / 104)),
      Paint()..color = _lime,
    );
  }
  final g = s * glyphFraction;
  canvas
    ..save()
    ..translate((s - g) / 2, (s - g) / 2)
    ..scale(g / info.size.width, g / info.size.height)
    ..drawPicture(info.picture)
    ..restore();

  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  info.picture.dispose();
}

void main() {
  testWidgets('generate brand images', (tester) async {
    await tester.runAsync(() async {
      // iOS / legacy icon: full-bleed lime, glyph at the Figma mark ratio.
      await _render('assets/brand/app_icon.png', 1024,
          glyphFraction: 56 / 104, background: _lime);
      // Android adaptive foreground (108dp canvas, 72dp visible).
      await _render('assets/brand/app_icon_foreground.png', 1024,
          glyphFraction: 56 / 104 * 72 / 108);
      // Native splash logo: the lime mark, 104dp at 4x.
      await _render('assets/brand/splash_logo.png', 416,
          glyphFraction: 56 / 104, markFraction: 1);
      // Android 12+ splash icon: 960px, shown inside a lime circle.
      await _render('assets/brand/splash_android12.png', 960,
          glyphFraction: 0.42);
    });
  });
}
