import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Spacing, radii and effects used across screens.
abstract final class AppDimens {
  static const double screenPadding = 20;
  static const double sectionGap = 14;

  static const double buttonHeight = 60;
  static const double inputHeight = 60;

  static const double radiusPill = 999;
  static const double radiusField = 18;
  static const double radiusRow = 22;
  static const double radiusCard = 26;
  static const double radiusMap = 28;

  /// Glow/Lime — drop shadow (0, 8) blur 24 spread -2, #C7FF2E @ 45%.
  static const List<BoxShadow> glowLime = [
    BoxShadow(
      color: AppColors.limeGlow,
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: -2,
    ),
  ];

  /// Lime button shadow — the Figma "Glow/Lime" effect (soft, not a band).
  static const List<BoxShadow> buttonGlow = glowLime;
}
