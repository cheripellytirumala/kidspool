import '../../../common/presentation/theme/app_assets.dart';

/// Design assets used by the RideTracking feature group (exported from
/// Figma: F22 · Live tracking, F23 · Ride completed, S19 / S20 alerts).
/// Shared icons are re-exported from [AppAssets].
abstract final class RideTrackingAssets {
  static const String _icons = 'assets/icons';

  // Shared (identical exports already in the design system)
  static const String arrowLeft = AppAssets.iconArrowLeft;
  static const String chat = AppAssets.iconChat;
  static const String car = AppAssets.iconCar;
  static const String shield = AppAssets.iconShield;
  static const String mapDark = AppAssets.mapDark;

  // F22 · Live tracking
  static const String phone = '$_icons/ride_phone.svg';
  static const String schoolPin = '$_icons/ride_pin.svg';

  // F20 · Start the ride (Ride Partner, before start)
  static const String startRoute = '$_icons/ride_start_route.svg';

  /// Icon/school (24px, ink) — identical export already bundled.
  static const String schoolIcon = '$_icons/profile_school_16.svg';

  // F23 · Ride completed
  static const String successCheck = '$_icons/ride_success_check.svg';
  static const String successCheckDriver =
      '$_icons/ride_success_check_driver.svg';
  static const String checkSmall = '$_icons/ride_check_small.svg';
  static const String locationPin = '$_icons/ride_location_pin.svg';
  static const String locationPin18 = '$_icons/ride_location_pin_18.svg';
  static const String home = '$_icons/ride_home.svg';
  static const String school = '$_icons/ride_school.svg';
  static const String clock = '$_icons/ride_clock.svg';
  static const String bell = '$_icons/ride_bell.svg';
  static const String done = '$_icons/ride_done.svg';
  static const String message = '$_icons/ride_message.svg';

  // S19 / S20 · Ride alerts
  static const String alertCar = '$_icons/ride_alert_car.svg';
  static const String alertCheck = '$_icons/ride_alert_check.svg';
  static const String alertMap = '$_icons/ride_alert_map.svg';
}
