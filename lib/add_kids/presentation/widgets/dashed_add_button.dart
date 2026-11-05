import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../core/constants/kids_assets.dart';
import '../../core/constants/kids_styles.dart';
import 'icon_disc.dart';

/// "Add · Child" — dashed 2px border/subtle outline (8 on / 4 off) with a
/// lime plus disc.
class DashedAddButton extends StatelessWidget {
  const DashedAddButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  static const double _radius = 22;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: CustomPaint(
        foregroundPainter: const _DashedBorderPainter(
          color: KidsColors.borderSubtle,
          radius: _radius,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(_radius),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                spacing: 12,
                children: [
                  const IconDisc(
                    asset: KidsAssets.plus,
                    size: 40,
                    iconSize: 20,
                    color: AppColors.lime,
                  ),
                  Expanded(child: Text(label, style: KidsTextStyles.labelL)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _strokeWidth = 2;
  static const double _dash = 8;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    final rect = (Offset.zero & size).deflate(_strokeWidth / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + _dash), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
