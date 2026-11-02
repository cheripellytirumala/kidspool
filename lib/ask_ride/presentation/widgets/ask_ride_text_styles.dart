import 'package:flutter/painting.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';

/// Figma text styles used by the AskRide screens that are not part of the
/// shared [AppTextStyles] set. All derive from the shared styles so the font
/// and leading behaviour stay identical.
abstract final class AskRideTextStyles {
  /// Label/L — 16/20 SemiBold, -0.5%. Field values, chip labels.
  static final TextStyle labelL = AppTextStyles.label.copyWith(
    height: 20 / 16,
    letterSpacing: -0.08,
  );

  /// Label/M — 14/18 SemiBold. Toggle rows, return route.
  static final TextStyle labelM = AppTextStyles.label.copyWith(
    fontSize: 14,
    height: 18 / 14,
  );

  /// 14/16 Medium secondary — field captions ("PICK UP FROM").
  static final TextStyle fieldCaption = AppTextStyles.caption.copyWith(
    fontSize: 14,
    height: 16 / 14,
  );

  /// 14/22 Regular secondary — option card subtitles, F20 step details.
  static final TextStyle optionSubtitle = AppTextStyles.body.copyWith(
    fontSize: 14,
  );

  /// Heading/H2 — 24/28 SemiBold, -1.5%. Sheet titles.
  static final TextStyle headingH2 = AppTextStyles.headingH3.copyWith(
    fontSize: 24,
    height: 28 / 24,
    letterSpacing: -0.36,
  );

  /// 17/24 SemiBold — calendar month.
  static final TextStyle month = AppTextStyles.bodyL.copyWith(
    fontWeight: FontWeight.w600,
    letterSpacing: -0.17,
  );

  /// 14/18 SemiBold secondary — calendar weekday letters.
  static final TextStyle weekdayLetter = labelM.copyWith(
    color: AppColors.textSecondary,
  );

  /// 14/20 Medium — weekday chips.
  static final TextStyle weekdayChip = AppTextStyles.bodyL.copyWith(
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: -0.07,
  );

  /// 14/16 Medium — "Swap".
  static final TextStyle swap = fieldCaption.copyWith(
    color: AppColors.textPrimary,
  );

  /// 15/20 SemiBold secondary — "Select Date".
  static final TextStyle selectDateCaption = AppTextStyles.label.copyWith(
    fontSize: 15,
    height: 20 / 15,
    letterSpacing: -0.075,
    color: AppColors.textSecondary,
  );

  /// 16/24 SemiBold — "Wednesday, Nov 4" in the date row.
  static final TextStyle selectDateValue = AppTextStyles.label.copyWith(
    height: 24 / 16,
    letterSpacing: -0.16,
  );

  /// 28/36 Medium, -2% — F20 headline.
  static final TextStyle successTitle = AppTextStyles.bodyL.copyWith(
    fontSize: 28,
    height: 36 / 28,
    letterSpacing: -0.56,
  );

  /// 17/24 Medium secondary — F20 subtitle.
  static final TextStyle successSubtitle = AppTextStyles.bodyL.copyWith(
    color: AppColors.textSecondary,
    letterSpacing: -0.085,
  );

  /// 15/20 SemiBold on dark — "Sent!" badge.
  static final TextStyle sentBadge = selectDateCaption.copyWith(
    color: AppColors.textOnDark,
  );

  /// 14/20 SemiBold secondary — "WHAT HAPPENS NEXT".
  static final TextStyle sectionCaption = labelM.copyWith(
    height: 20 / 14,
    letterSpacing: -0.07,
    color: AppColors.textSecondary,
  );

  /// 18/24 SemiBold — F20 buttons.
  static final TextStyle actionButton = AppTextStyles.title.copyWith(
    height: 24 / 18,
    letterSpacing: -0.18,
  );

  /// 20/24 SemiBold — sheet "Done" button.
  static final TextStyle doneButton = AppTextStyles.headingH3;
}
