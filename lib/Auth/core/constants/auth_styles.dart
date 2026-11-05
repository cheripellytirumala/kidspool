import 'package:flutter/painting.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';

/// Figma color variables used by the Auth screens that are not (yet) part of
/// the shared `AppColors` tokens.
abstract final class AuthColors {
  /// brand/charcoal — unselected chip on dark screens.
  static const Color charcoal = Color(0xFF2E2E2E);

  /// bg/inverse-raised — hint pills on the camera screen.
  static const Color inverseRaised = Color(0xFF1C1C1C);

  /// border/dark — divider inside the dark ID summary card.
  static const Color borderDark = Color(0xFF2E2E2E);

  /// Scrim behind the OTP bottom sheet (#0A0A0A @ 55%).
  static const Color scrim = Color(0x8C0A0A0A);

  /// Camera view radial gradient stops.
  static const Color cameraCenter = Color(0xFF383838);
  static const Color cameraMid = Color(0xFF242424);

  /// Gallery thumbnail (last photo in the camera roll).
  static const Color thumbBackground = Color(0xFF8C8070);
  static const Color thumbCardStart = Color(0xFFEDF5FC);
  static const Color thumbCardEnd = Color(0xFFD1E3F7);
  static const Color thumbCardBorder = Color(0xFFB2C2D6);
  static const Color thumbCardBand = Color(0xFF1F458C);
  static const Color thumbCardLine = Color(0xFF596B85);
}

/// Text styles from Figma that are only used inside the Auth group.
abstract final class AuthTextStyles {
  /// Heading/H2 — 24/28 SemiBold, -1.5%.
  static final TextStyle headingH2 = AppTextStyles.headingH3.copyWith(
    fontSize: 24,
    height: 28 / 24,
    letterSpacing: -0.36,
  );

  /// Label/M — 14/18 SemiBold.
  static final TextStyle labelM = AppTextStyles.label.copyWith(
    fontSize: 14,
    height: 18 / 14,
  );

  /// Label/L — 16/20 SemiBold, -0.5%.
  static final TextStyle labelL = AppTextStyles.label.copyWith(
    height: 20 / 16,
    letterSpacing: -0.08,
  );

  /// Caption/S — 14/16 Medium.
  static final TextStyle captionS = AppTextStyles.caption.copyWith(
    fontSize: 14,
    height: 16 / 14,
  );

  /// Body/S — 14/18 Regular.
  static final TextStyle bodyS = AppTextStyles.body.copyWith(
    fontSize: 14,
    height: 18 / 14,
    color: AppColors.textOnDarkMuted,
  );
}
