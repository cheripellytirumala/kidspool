import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static final ButtonStyle _inkTextButton = TextButton.styleFrom(
    foregroundColor: AppColors.ink,
    textStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
  );

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
      // Lime text is unreadable on white: dialog / text buttons use ink.
      textButtonTheme: TextButtonThemeData(style: _inkTextButton),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.screen,
        surfaceTintColor: Colors.transparent,
        headerForegroundColor: AppColors.textPrimary,
        cancelButtonStyle: _inkTextButton,
        confirmButtonStyle: _inkTextButton,
        // Today: ink ring instead of a lime one on white.
        todayForegroundColor: const WidgetStatePropertyAll(
          AppColors.textPrimary,
        ),
        todayBorder: const BorderSide(color: AppColors.ink),
        // Typed-date field (pencil): ink label and border, not lime.
        inputDecorationTheme: InputDecorationTheme(
          floatingLabelStyle: const TextStyle(color: AppColors.textPrimary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.ink, width: 2),
          ),
        ),
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.textOnLime
              : states.contains(WidgetState.disabled)
              ? AppColors.textPrimary.withValues(alpha: 0.3)
              : AppColors.textPrimary,
        ),
        yearForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.textOnLime
              : states.contains(WidgetState.disabled)
              ? AppColors.textPrimary.withValues(alpha: 0.3)
              : AppColors.textPrimary,
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.ink,
        selectionColor: AppColors.lime,
        selectionHandleColor: AppColors.ink,
      ),
    );
  }
}
