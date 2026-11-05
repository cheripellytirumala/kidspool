import 'package:flutter/painting.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';

/// Home-specific text styles from the Figma frames that are not part of the
/// shared [AppTextStyles] set. Letter spacing is in logical pixels.
abstract final class HomeTextStyles {
  static TextStyle _style(
    double size,
    double lineHeight,
    FontWeight weight, {
    double letterSpacing = 0,
    Color color = AppColors.textPrimary,
  }) {
    return TextStyle(
      fontFamily: AppTextStyles.fontFamily,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  /// "Wednesday, Nov 4" — 15/20 SemiBold, secondary.
  static final TextStyle dateLabel = _style(
    15,
    20,
    FontWeight.w600,
    letterSpacing: -0.075,
    color: AppColors.textSecondary,
  );

  /// "Hi Sarah," — 38/44 Regular.
  static final TextStyle greeting = _style(
    38,
    44,
    FontWeight.w400,
    letterSpacing: -1.14,
  );

  /// Heading/H2 — 24/28 SemiBold (action titles, sheet titles).
  static final TextStyle headingH2 = _style(
    24,
    28,
    FontWeight.w600,
    letterSpacing: -0.36,
  );

  /// Hero card title — 22/28 SemiBold.
  static final TextStyle heroTitle = _style(
    22,
    28,
    FontWeight.w600,
    letterSpacing: -0.33,
  );

  /// Family row name — 19/24 SemiBold.
  static final TextStyle familyName = _style(
    19,
    24,
    FontWeight.w600,
    letterSpacing: -0.19,
  );

  /// "Select All" — 19/22 SemiBold.
  static final TextStyle selectAll = _style(19, 22, FontWeight.w600);

  /// Body/M — 15/22 Regular, secondary.
  static final TextStyle bodyM = _style(
    15,
    22,
    FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Label/L — 16/20 SemiBold.
  static final TextStyle labelL = _style(
    16,
    20,
    FontWeight.w600,
    letterSpacing: -0.08,
  );

  /// Label/M — 14/18 SemiBold.
  static final TextStyle labelM = _style(14, 18, FontWeight.w600);

  /// Caption/M — 14/16 Medium, secondary.
  static final TextStyle captionM = _style(
    14,
    16,
    FontWeight.w500,
    color: AppColors.textSecondary,
  );

  /// Button/L label — 20/24 SemiBold ("Say Hi").
  static final TextStyle buttonL = _style(
    20,
    24,
    FontWeight.w600,
    letterSpacing: -0.2,
  );

  // H3 · Home · Both

  /// "Your kid’s ride" — 18/20 SemiBold.
  static final TextStyle sectionTitle = _style(
    18,
    20,
    FontWeight.w600,
    letterSpacing: -0.09,
  );

  /// "Jen drives Emma" on the map chip — 16/18 SemiBold, on dark.
  static final TextStyle mapChip = _style(
    16,
    18,
    FontWeight.w600,
    color: AppColors.textOnDark,
  );

  /// "Track" — 16/18 SemiBold.
  static final TextStyle mapButton = _style(16, 18, FontWeight.w600);

  /// "Home · 8:30 AM" — 15/16 Medium, on-dark muted.
  static final TextStyle mapCaption = _style(
    15,
    16,
    FontWeight.w500,
    color: AppColors.textOnDarkMuted,
  );

  /// "Lincoln" pin label — 15/16 Medium, lime.
  static final TextStyle mapPin = _style(
    15,
    16,
    FontWeight.w500,
    color: AppColors.lime,
  );

  /// "YOUR RIDE GROUP" — 15/20 SemiBold, secondary.
  static final TextStyle groupLabel = dateLabel;

  /// "Home → Lincoln parents" — 17/24 SemiBold.
  static final TextStyle groupTitle = _style(
    17,
    24,
    FontWeight.w600,
    letterSpacing: -0.17,
  );

  /// Label/S — 12/16 Medium, secondary ("FAMILIES").
  static final TextStyle captionS = _style(
    12,
    16,
    FontWeight.w500,
    color: AppColors.textSecondary,
  );
}
