import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: AppTextStyles.fontFamily,
      scaffoldBackgroundColor: AppColors.screen,
      colorScheme: const ColorScheme.light(
        primary: AppColors.lime,
        onPrimary: AppColors.textOnLime,
        secondary: AppColors.ink,
        onSecondary: AppColors.textOnDark,
        surface: AppColors.screen,
        onSurface: AppColors.textPrimary,
        error: Color(0xFFD92D20),
      ),
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: AppTextStyles.displayL,
        titleLarge: AppTextStyles.headingH3,
        titleMedium: AppTextStyles.title,
        bodyLarge: AppTextStyles.bodyL,
        bodyMedium: AppTextStyles.body,
        labelLarge: AppTextStyles.label,
        bodySmall: AppTextStyles.caption,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.screen,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.ink,
        selectionColor: AppColors.lime,
        selectionHandleColor: AppColors.ink,
      ),
    );
  }
}
