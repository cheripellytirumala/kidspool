import 'package:flutter/painting.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';

/// Ride-day tokens from Figma that the shared design system doesn't have.
abstract final class RideColors {
  /// status/sos
  static const Color sos = Color(0xFFFF4D3D);

  /// border/dark — dividers on the dark stats card.
  static const Color borderDark = Color(0xFF2E2E2E);

  /// Muted grey of the driver variant's thank-you line.
  static const Color muted = Color(0xFF6B6B6B);

  /// Dotted "still to drive" route on the map.
  static const Color routeAhead = Color(0xFF9A9A9A);
}

/// Shadows from the Figma effect styles.
abstract final class RideShadows {
  /// Shadow/Float — (0, 16) blur 40 spread -4, #000 @ 16%.
  static const List<BoxShadow> float = [
    BoxShadow(
      color: Color(0x29000000),
      offset: Offset(0, 16),
      blurRadius: 40,
      spreadRadius: -4,
    ),
  ];

  /// Shadow/Sheet — (0, -8) blur 32, #000 @ 18%.
  static const List<BoxShadow> sheet = [
    BoxShadow(color: Color(0x2E000000), offset: Offset(0, -8), blurRadius: 32),
  ];
}

/// Figma text styles used on ride-day screens (Hanken Grotesk).
abstract final class RideTextStyles {
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

  /// Label/S — 12/16 Medium.
  static final TextStyle labelS = _s(
    12,
    16,
    FontWeight.w500,
    color: AppColors.textSecondary,
  );

  /// Label/M — 14/18 SemiBold.
  static final TextStyle labelM = _s(14, 18, FontWeight.w600);

  /// Label/L — 16/20 SemiBold.
  static final TextStyle labelL = _s(
    16,
    20,
    FontWeight.w600,
    letterSpacing: -0.08,
  );

  /// Number/XL — 40/44 Bold.
  static final TextStyle numberXL = _s(
    40,
    44,
    FontWeight.w700,
    letterSpacing: -1,
  );

  /// Number/L — 28/32 Bold, lime on the dark stats card.
  static final TextStyle numberL = _s(
    28,
    32,
    FontWeight.w700,
    letterSpacing: -0.42,
    color: AppColors.lime,
  );

  /// Body/S — 13/18 Regular.
  static final TextStyle bodyS = _s(
    13,
    18,
    FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// F23 headline — 28/36 Medium.
  static final TextStyle completedTitle = _s(
    28,
    36,
    FontWeight.w500,
    letterSpacing: -0.56,
  );

  /// F23 driver headline — 26/36 Medium.
  static final TextStyle droppedOffTitle = _s(
    26,
    36,
    FontWeight.w500,
    letterSpacing: -0.52,
  );

  /// Ink pill ("Ride completed") — 15/20 SemiBold, white.
  static final TextStyle pill = _s(
    15,
    20,
    FontWeight.w600,
    letterSpacing: -0.075,
    color: AppColors.textOnDark,
  );

  /// Trip summary kid names — 18/24 SemiBold.
  static final TextStyle kidName = _s(
    18,
    24,
    FontWeight.w600,
    letterSpacing: -0.18,
  );

  /// Trip summary row label — 16/24 Medium.
  static final TextStyle rowLabel = _s(
    16,
    24,
    FontWeight.w500,
    letterSpacing: -0.08,
  );

  /// Trip summary row value — 16/20 SemiBold.
  static final TextStyle rowValue = labelL;

  /// Secondary 14/22 Regular (vehicle line, "She got …").
  static final TextStyle body14 = _s(
    14,
    22,
    FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// 15/22 Regular secondary ("Jen confirmed drop-off").
  static final TextStyle body15 = _s(
    15,
    22,
    FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// 17/24 Medium secondary ("Lincoln Elementary · 8:47 AM").
  static final TextStyle body17 = _s(
    17,
    24,
    FontWeight.w500,
    letterSpacing: -0.085,
    color: AppColors.textSecondary,
  );

  /// 17/20 SemiBold ("Sarah has been told").
  static final TextStyle title17 = _s(
    17,
    20,
    FontWeight.w600,
    letterSpacing: -0.085,
  );

  /// F23 big pill buttons ("Done", "Message Sarah") — 19/24 SemiBold.
  static final TextStyle buttonXL = _s(
    19,
    24,
    FontWeight.w600,
    letterSpacing: -0.19,
  );

  /// Alert card meta — 14/18 SemiBold secondary ("KIDPOOL · now").
  static final TextStyle alertMeta = _s(
    14,
    18,
    FontWeight.w600,
    color: AppColors.textSecondary,
  );

  /// Alert card button — 17/20 SemiBold white.
  static final TextStyle alertButton = _s(
    17,
    20,
    FontWeight.w600,
    letterSpacing: -0.085,
    color: AppColors.textOnDark,
  );
}
