import 'package:flutter/widgets.dart';

import '../../../common/presentation/widgets/app_icon.dart';

/// Filled circle with a centered SVG icon (Figma icon "Frame" discs).
class IconDisc extends StatelessWidget {
  const IconDisc({
    super.key,
    required this.asset,
    required this.size,
    required this.iconSize,
    required this.color,
    this.iconColor,
    this.border,
  });

  final String asset;
  final double size;
  final double iconSize;
  final Color color;
  final Color? iconColor;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: border,
      ),
      child: AppIcon(asset, size: iconSize, color: iconColor),
    );
  }
}
