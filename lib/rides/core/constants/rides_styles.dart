import 'package:flutter/painting.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';

/// Tokens of F19c · Your rides that are not in the shared theme.
abstract final class RidesStyles {
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

  /// "Requests to help, upcoming rides and history" — 14/18 SemiBold.
  static final TextStyle subtitle = _s(
    14,
    18,
    FontWeight.w600,
    color: AppColors.textSecondary,
  );

  /// Label/M — tabs, toggle row, buttons: 14/18 SemiBold.
  static final TextStyle labelM = _s(14, 18, FontWeight.w600);

  /// Card title — 14/20 SemiBold, -0.07.
  static final TextStyle cardTitle = _s(
    14,
    20,
    FontWeight.w600,
    letterSpacing: -0.07,
  );

  /// Label/S — 12/16 Medium (card meta, section label, chips, badge).
  static final TextStyle labelS = _s(12, 16, FontWeight.w500);

  static final TextStyle meta = labelS.copyWith(color: AppColors.textSecondary);

  /// "View request" glow — (0, 8) blur 12, lime @ 45%.
  static const List<BoxShadow> buttonGlow = [
    BoxShadow(color: AppColors.limeGlow, offset: Offset(0, 8), blurRadius: 12),
  ];
}
