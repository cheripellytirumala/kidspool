import 'package:flutter/painting.dart';

/// Color tokens from the KidPool Figma design system (accessibility version).
abstract final class AppColors {
  // Brand
  static const Color lime = Color(0xFFC7FF2E); // brand/lime
  static const Color ink = Color(0xFF0F0F0F); // brand/ink
  static const Color limeTint = Color(0xFFEEFFC4); // selected card bg

  // Backgrounds
  static const Color screen = Color(0xFFFFFFFF); // bg/screen
  static const Color surface = Color(0xFFF2F2F2); // bg/surface
  static const Color surfaceStrong = Color(0xFFE6E6E6); // bg/surface-strong
  static const Color inverse = Color(0xFF0F0F0F); // bg/inverse
  static const Color mapDark = Color(0xFF141414);

  // Text
  static const Color textPrimary = Color(0xFF0F0F0F); // text/primary
  static const Color textSecondary = Color(0xFF666666); // a11y/text-secondary
  static const Color textOnLime = Color(0xFF0F0F0F); // text/on-lime
  static const Color textOnDark = Color(0xFFFFFFFF); // text/on-dark
  static const Color textOnDarkMuted = Color(
    0xFFB3B3B3,
  ); // a11y/text-on-dark-muted

  // Borders
  static const Color borderField = Color(0xFF8C8C8C); // a11y/border-field

  /// Glow/Lime effect color (#C7FF2E at 45%).
  static const Color limeGlow = Color(0x73C7FF2E);

  // Feedback
  /// Inline error text (WCAG AA on white).
  static const Color danger = Color(0xFFC62828);
}
