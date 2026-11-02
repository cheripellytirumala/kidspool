import 'package:flutter/painting.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';

/// Kids-flow colors that are not (yet) part of the shared tokens.
abstract final class KidsColors {
  static const Color charcoal = Color(0xFF2E2E2E); // brand/charcoal
  static const Color inverseRaised = Color(0xFF1C1C1C); // bg/inverse-raised
  static const Color scrim = Color(0x8C0A0A0A); // rgba(10,10,10,0.55)
}

/// Figma text styles used by the Kids flow, derived from [AppTextStyles].
abstract final class KidsTextStyles {
  /// Heading/H2 — 24/28 SemiBold, -1.5%.
  static final TextStyle headingH2 = AppTextStyles.headingH3.copyWith(
    fontSize: 24,
    height: 28 / 24,
    letterSpacing: -0.36,
  );

  /// 18/24 SemiBold, -1% (selected search result).
  static final TextStyle titleL = AppTextStyles.title.copyWith(
    height: 24 / 18,
    letterSpacing: -0.18,
  );

  /// Label/L — 16/20 SemiBold, -0.5%.
  static final TextStyle labelL = AppTextStyles.label.copyWith(
    height: 20 / 16,
    letterSpacing: -0.08,
  );

  /// Label/M — 14/18 SemiBold.
  static final TextStyle labelM = AppTextStyles.label.copyWith(
    fontSize: 14,
    height: 18 / 14,
  );

  /// 15/20 SemiBold (Edit pill).
  static final TextStyle labelS = AppTextStyles.label.copyWith(
    fontSize: 15,
    height: 20 / 15,
    letterSpacing: -0.075,
  );

  /// Body/M — 15/22 Regular, secondary.
  static final TextStyle bodyM = AppTextStyles.body.copyWith(fontSize: 15);

  /// Caption/M — 14/16 Medium, secondary.
  static final TextStyle captionM = AppTextStyles.caption.copyWith(
    fontSize: 14,
  );

  /// 14/18 Regular, primary (tip copy).
  static final TextStyle bodyS = AppTextStyles.body.copyWith(
    fontSize: 14,
    height: 18 / 14,
    color: AppColors.textPrimary,
  );
}
