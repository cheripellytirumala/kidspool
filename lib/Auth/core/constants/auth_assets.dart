/// Paths of design assets used only by the Auth screens (exported from Figma).
///
/// Shared icons (phone, shield, camera, home, …) live in `AppAssets`.
abstract final class AuthAssets {
  static const String _icons = 'assets/icons';
  static const String _images = 'assets/images';

  /// Icon/arrow-left — 24px, back buttons on V1 / V3.
  static const String iconArrowLeft = '$_icons/icon_arrow_left.svg';

  /// Message bubble — 16px, "Filled in from your messages" chip on S03a.
  static const String iconMessage = '$_icons/icon_message.svg';

  /// Car — "I can offer and request rides" role card (selected state).
  static const String iconCar = '$_icons/icon_car.svg';

  /// Shield with check — "DRIVER LICENSE" header on V3.
  static const String iconShieldCheck = '$_icons/icon_shield_check.svg';

  /// Small house glyph (19×18.2) used in the address input and map pin.
  static const String iconHomeGlyph = '$_icons/icon_home.svg';

  /// Lime corner brackets around the ID while scanning (320×210).
  static const String scanIdFrame = '$_images/scan_id_frame.svg';

  /// Demo ID portrait (Sarah) shown on V3 and the gallery thumbnail on V1.
  static const String idPortrait = '$_images/avatar_sarah.png';
}
