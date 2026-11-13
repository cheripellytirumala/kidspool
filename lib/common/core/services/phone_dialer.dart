import 'package:url_launcher/url_launcher.dart';

/// Opens the phone's dialer with a number filled in (the user still taps
/// the call button there).
abstract final class PhoneDialer {
  /// Replaced in tests.
  static Future<bool> Function(Uri uri) launcher = _launch;

  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  /// `+1 (233) 221-1322` → `tel:+12332211322`; null without any digits.
  static Uri? telUri(String phone) {
    final trimmed = phone.trim();
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return Uri(
      scheme: 'tel',
      path: trimmed.startsWith('+') ? '+$digits' : digits,
    );
  }

  /// Opens the dialer with [phone]. False when there's no number or the
  /// device can't dial (e.g. the iOS Simulator, a tablet without a phone).
  static Future<bool> dial(String phone) async {
    final uri = telUri(phone);
    if (uri == null) return false;
    try {
      return await launcher(uri);
    } catch (_) {
      return false;
    }
  }
}
