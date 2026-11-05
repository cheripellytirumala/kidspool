import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Typography from Figma. Font: Hanken Grotesk (bundled in assets/fonts).
///
/// Figma letter spacing is in % of font size; values below are converted to
/// logical pixels.
abstract final class AppTextStyles {
  static const String fontFamily = 'HankenGrotesk';

  static TextStyle _style(
    double size,
    double lineHeight,
    FontWeight weight, {
    double letterSpacingPercent = 0,
    Color color = AppColors.textPrimary,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: size * letterSpacingPercent / 100,
      color: color,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  /// Display/L — 44/44 Regular, -3%. Screen headlines.
  static final TextStyle displayL = _style(
    44,
    44,
    FontWeight.w400,
    letterSpacingPercent: -3,
  );

  /// Heading/H3 — 20/24 SemiBold, -1%. Large field values.
  static final TextStyle headingH3 = _style(
    20,
    24,
    FontWeight.w600,
    letterSpacingPercent: -1,
  );

  /// Title — 18/20 SemiBold, -0.5%. Buttons, card titles, field values.
  static final TextStyle title = _style(
    18,
    20,
    FontWeight.w600,
    letterSpacingPercent: -0.5,
  );

  /// Body/L — 17/24 Medium, -0.5%. Inputs and body copy.
  static final TextStyle bodyL = _style(
    17,
    24,
    FontWeight.w500,
    letterSpacingPercent: -0.5,
  );

  /// Body — 16/22 Regular, secondary. Screen subtitles.
  static final TextStyle body = _style(
    16,
    22,
    FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Label — 16/18 SemiBold. Chips, checkbox rows.
  static final TextStyle label = _style(16, 18, FontWeight.w600);

  /// Caption — 15/16 Medium, secondary. Field labels, helper text.
  static final TextStyle caption = _style(
    15,
    16,
    FontWeight.w500,
    color: AppColors.textSecondary,
  );
}
