import 'package:flutter/painting.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';

/// Messages-only tokens from Figma F24 / F24a / A7a / F19 / GC6 that are not
/// in the shared theme.
abstract final class MessagesStyles {
  /// Thread background behind the bubbles.
  static const Color threadBackground = Color(0xFFF9F9F9);

  /// `status/sos` — "Leave" text.
  static const Color sos = Color(0xFFFF4D3D);

  /// `brand/lime-soft`.
  static const Color limeSoft = AppColors.limeTint;

  static const double radiusThread = 22;
  static const double radiusRequest = 24;
  static const double radiusRow = 20;
  static const double radiusBubble = 20;
  static const double radiusBubbleTail = 6;

  /// F19 bubble width (max; short messages shrink-wrap).
  static const double bubbleWidth = 268;

  /// F19 in-chat "Ride request card" width.
  static const double rideCardWidth = 290;

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

  /// Label/L — 16/20 SemiBold, -0.08. Row titles, card lines, buttons.
  static final TextStyle labelL = _s(
    16,
    20,
    FontWeight.w600,
    letterSpacing: -0.08,
  );

  /// Label/M — 14/18 SemiBold. Search hint, unread preview, day pills.
  static final TextStyle labelM = _s(14, 18, FontWeight.w600);

  /// Label/S — 12/16 Medium, secondary. Times, previews, subtitles.
  static final TextStyle labelS = _s(
    12,
    16,
    FontWeight.w500,
    color: AppColors.textSecondary,
  );

  /// Tab label / card title — 17/20 SemiBold, -0.085.
  static final TextStyle tab = _s(
    17,
    20,
    FontWeight.w600,
    letterSpacing: -0.085,
  );

  /// Card subtitle — 14/22 Regular, secondary.
  static final TextStyle meta = _s(
    14,
    22,
    FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Section label — 15/20 SemiBold, -0.075, secondary ("RIDE REQUESTS · 2").
  static final TextStyle section = _s(
    15,
    20,
    FontWeight.w600,
    letterSpacing: -0.075,
    color: AppColors.textSecondary,
  );

  /// Footer hint — 15/22 Regular, secondary.
  static final TextStyle hint = _s(
    15,
    22,
    FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Bubble body — 17/24 Medium, -0.085.
  static final TextStyle bubble = _s(
    17,
    24,
    FontWeight.w500,
    letterSpacing: -0.085,
  );

  /// A7a summary title — 18/20 SemiBold, -0.09.
  static final TextStyle summaryTitle = _s(
    18,
    20,
    FontWeight.w600,
    letterSpacing: -0.09,
  );

  /// A7a summary subtitle / chips — 15/16 Medium, secondary.
  static final TextStyle summaryMeta = _s(
    15,
    16,
    FontWeight.w500,
    color: AppColors.textSecondary,
  );

  /// A7a parent's note — 15/18 Regular.
  static final TextStyle note = _s(15, 18, FontWeight.w400);

  /// GC6 title — Heading/H2 24/28 SemiBold, -0.36.
  static final TextStyle heading = _s(
    24,
    28,
    FontWeight.w600,
    letterSpacing: -0.36,
  );

  /// GC6 subtitle — 16/24 Medium, -0.08, secondary.
  static final TextStyle groupMeta = _s(
    16,
    24,
    FontWeight.w500,
    letterSpacing: -0.08,
    color: AppColors.textSecondary,
  );
}
