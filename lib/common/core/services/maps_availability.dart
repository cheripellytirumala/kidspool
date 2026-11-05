import 'package:flutter/services.dart';

/// Whether the native Google Maps SDK has an API key on this device.
///
/// Creating a `GoogleMap` without one crashes the app on iOS (Google's SDK
/// throws), so every screen must check this before showing a map and fall
/// back to a map-less layout when it's `false`. Also `false` in widget tests,
/// where the native side isn't present.
abstract final class MapsAvailability {
  static const MethodChannel _channel = MethodChannel('kidpool/maps');
  static Future<bool>? _configured;

  static Future<bool> isNativeMapConfigured() => _configured ??= _query();

  static Future<String?>? _apiKey;

  /// The key from the native config (Secrets.xcconfig / local.properties),
  /// so Places search works without `--dart-define`. `null` if not set.
  static Future<String?> nativeApiKey() => _apiKey ??= _queryKey();

  static Future<String?> _queryKey() async {
    try {
      final key = await _channel.invokeMethod<String>('apiKey');
      return key == null || key.trim().isEmpty ? null : key.trim();
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<bool> _query() async {
    try {
      return await _channel.invokeMethod<bool>('isConfigured') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
