import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Status / navigation bar styles. Flutter's `SystemUiOverlayStyle.dark`
/// and `.light` both paint the Android navigation bar black, which showed
/// as a black bar under light screens; these keep it the screen's color.
abstract final class AppSystemUi {
  /// Light screens: dark status-bar icons, white navigation bar.
  static const SystemUiOverlayStyle dark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.screen,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  /// Dark screens (splash, ID scan): light icons, dark navigation bar.
  static const SystemUiOverlayStyle light = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.inverse,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );
}
