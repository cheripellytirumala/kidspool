import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../core/constants/auth_assets.dart';

/// Camera overlay on V1: a ghost ID card, lime corner brackets and a glowing
/// scan line sweeping across the card.
class IdViewfinder extends StatefulWidget {
  const IdViewfinder({super.key});

  static const Size size = Size(320, 210);

  @override
  State<IdViewfinder> createState() => _IdViewfinderState();
}

class _IdViewfinderState extends State<IdViewfinder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
    // Start where Figma draws the line (102px into the 210px frame).
    value: 0.5,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: IdViewfinder.size,
      child: Stack(
        children: [
          const Positioned(
            left: 10,
            top: 10,
            width: 300,
            height: 190,
            child: _GhostCard(),
          ),
          Positioned.fill(child: SvgPicture.asset(AuthAssets.scanIdFrame)),
          AnimatedBuilder(
            animation: _sweep,
            builder: (context, child) => Positioned(
              left: 20,
              width: 280,
              // Sweep inside the card (top 20 → 182), centered at 102.
              top: 20 + 162 * Curves.easeInOut.transform(_sweep.value),
              height: 3,
              child: child!,
            ),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.lime,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xE6C7FF2E),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostCard extends StatelessWidget {
  const _GhostCard();

  static Widget _bar(double left, double top, double width, {Color? color}) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: 10,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? const Color(0x1FFFFFFF),
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: const Color(0x14FFFFFF),
        child: Stack(
          children: [
            Positioned(
              left: 20,
              top: 22,
              width: 120,
              height: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x80C7FF2E),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            Positioned(
              left: 20,
              top: 50,
              width: 72,
              height: 90,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x24FFFFFF),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            _bar(110, 52, 150),
            _bar(110, 74, 110),
            _bar(110, 104, 170),
            _bar(110, 126, 90),
          ],
        ),
      ),
    );
  }
}
