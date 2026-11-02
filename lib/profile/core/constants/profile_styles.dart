import 'package:flutter/painting.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';

/// Profile-only tokens from Figma S18 that are not in the shared theme.
abstract final class ProfileStyles {
  /// `status/sos` — log out text.
  static const Color sos = Color(0xFFFF4D3D);

  /// `status/sos` at 12% — log out icon tile.
  static const Color sosTint = Color(0x1FFF4D3D);

  static TextStyle _s(
    double size,
    double height,
    FontWeight weight, {
    double letterSpacing = 0,
    Color color = AppColors.textPrimary,
  }) => TextStyle(
    fontFamily: AppTextStyles.fontFamily,
    fontSize: size,
    height: height / size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    color: color,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Name — 32/44 Regular, -0.96.
  static final TextStyle name = _s(
    32,
    44,
    FontWeight.w400,
    letterSpacing: -0.96,
  );

  /// Phone · city — 16/24 Medium, -0.08, secondary.
  static final TextStyle meta = _s(
    16,
    24,
    FontWeight.w500,
    letterSpacing: -0.08,
    color: AppColors.textSecondary,
  );

  /// Header badges — 14/20 SemiBold, -0.07.
  static final TextStyle badge = _s(
    14,
    20,
    FontWeight.w600,
    letterSpacing: -0.07,
  );

  /// "Edit my details" — 16/20 SemiBold, -0.08.
  static final TextStyle button = _s(
    16,
    20,
    FontWeight.w600,
    letterSpacing: -0.08,
  );

  /// Section label — 15/20 SemiBold, -0.075, secondary.
  static final TextStyle section = _s(
    15,
    20,
    FontWeight.w600,
    letterSpacing: -0.075,
    color: AppColors.textSecondary,
  );

  /// Row title — 17/20 SemiBold, -0.085.
  static final TextStyle rowTitle = _s(
    17,
    20,
    FontWeight.w600,
    letterSpacing: -0.085,
  );

  /// Row subtitle — 14/22 Regular, secondary.
  static final TextStyle rowSubtitle = _s(
    14,
    22,
    FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Kid name — 18/24 SemiBold, -0.18.
  static final TextStyle kidName = _s(
    18,
    24,
    FontWeight.w600,
    letterSpacing: -0.18,
  );

  /// Kid places line — 14/22 Regular, primary.
  static final TextStyle kidPlaces = _s(14, 22, FontWeight.w400);

  /// Expanded kid name — 18/20 SemiBold, -0.09.
  static final TextStyle cardTitle = _s(
    18,
    20,
    FontWeight.w600,
    letterSpacing: -0.09,
  );

  /// Expanded kid subtitle / place schedule — 15/16 Medium, secondary.
  static final TextStyle cardSubtitle = _s(
    15,
    16,
    FontWeight.w500,
    color: AppColors.textSecondary,
  );

  /// Place name / inline actions — 16/18 SemiBold.
  static final TextStyle placeTitle = _s(16, 18, FontWeight.w600);

  /// Status pill on a row ("Verified") — 13/18 SemiBold.
  static final TextStyle pill = _s(13, 18, FontWeight.w600);
}
