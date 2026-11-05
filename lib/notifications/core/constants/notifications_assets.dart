import '../../../common/presentation/theme/app_assets.dart';

/// Icons of F25b · Notifications (exported from Figma, 19px ink strokes on
/// a white 40px circle).
abstract final class NotificationsAssets {
  static const String _icons = 'assets/icons';

  /// Icon/arrow-left — identical export already bundled.
  static const String arrowLeft = AppAssets.iconArrowLeft;

  /// "Bluewave Swim School was added" — a new ride request to answer.
  static const String inbox = '$_icons/notif_inbox.svg';

  /// "Thursday’s ride reopened" — a ride that needs attention.
  static const String bell = '$_icons/notif_bell.svg';

  /// "Service paused in 94102" — ride on the way / arrived.
  static const String pin = '$_icons/notif_pin.svg';
}
