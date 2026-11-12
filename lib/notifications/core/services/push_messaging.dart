import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../common/core/utils/logger.dart';

/// Remote push (Firebase Cloud Messaging), dormant until the app has
/// Firebase config (GoogleService-Info.plist / google-services.json, added
/// by `flutterfire configure`). See docs/backend/2026-11-10_push_setup.md.
///
/// Messages are exposed as their `data` maps: `{kind, requestId}`.
abstract interface class PushMessaging {
  /// Starts Firebase. False (and every other member inert) when the app
  /// has no Firebase config. Never throws.
  Future<bool> init();

  /// True once [init] succeeded.
  bool get isAvailable;

  /// Shows the system prompt if it hasn't been answered. True when allowed.
  Future<bool> requestPermission();

  /// This device's FCM token; null when there isn't one (yet).
  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  /// Pushes received while the app is in the foreground.
  Stream<Map<String, dynamic>> get onMessage;

  /// Pushes the user tapped while the app was in the background.
  Stream<Map<String, dynamic>> get onMessageOpenedApp;

  /// The push whose tap launched the app, if any.
  Future<Map<String, dynamic>?> getInitialMessage();
}

class FirebasePushMessaging implements PushMessaging {
  bool _available = false;

  @override
  bool get isAvailable => _available;

  @override
  Future<bool> init() async {
    try {
      // No options: reads the native config files. Throws without them.
      await Firebase.initializeApp();
      _available = true;
    } catch (error) {
      AppLogger.info(
        'Firebase is not configured; push notifications are off ($error)',
        tag: 'Push',
      );
      _available = false;
    }
    return _available;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_available) return false;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (error) {
      AppLogger.warning('Push permission failed: $error', tag: 'Push');
      return false;
    }
  }

  @override
  Future<String?> getToken() async {
    if (!_available) return null;
    try {
      final messaging = FirebaseMessaging.instance;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // The FCM token needs the APNs token, which arrives shortly after
        // launch (and never without the Push Notifications capability).
        for (var i = 0; i < 5; i++) {
          if (await messaging.getAPNSToken() != null) break;
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        if (await messaging.getAPNSToken() == null) return null;
      }
      // The registration token FCM HTTP v1 sends to (`message.token`). The
      // newer FID `register()` API targets direct-send instead.
      // ignore: deprecated_member_use
      return await messaging.getToken();
    } catch (error) {
      AppLogger.warning('No FCM token: $error', tag: 'Push');
      return null;
    }
  }

  @override
  Stream<String> get onTokenRefresh => _available
      // Pairs with getToken() above.
      // ignore: deprecated_member_use
      ? FirebaseMessaging.instance.onTokenRefresh
      : const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onMessage => _available
      ? FirebaseMessaging.onMessage.map((m) => m.data)
      : const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onMessageOpenedApp => _available
      ? FirebaseMessaging.onMessageOpenedApp.map((m) => m.data)
      : const Stream.empty();

  @override
  Future<Map<String, dynamic>?> getInitialMessage() async {
    if (!_available) return null;
    try {
      return (await FirebaseMessaging.instance.getInitialMessage())?.data;
    } catch (error) {
      AppLogger.warning('getInitialMessage failed: $error', tag: 'Push');
      return null;
    }
  }
}
