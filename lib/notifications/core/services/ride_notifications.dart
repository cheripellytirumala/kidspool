import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../common/core/utils/logger.dart';
import '../../../ride_tracking/core/utils/ride_alert_payload.dart';
import '../../../ride_tracking/domain/entities/ride_alert.dart';
import '../../../ride_tracking/domain/repositories/ride_alert_notifier.dart';
import '../../domain/repositories/push_tokens_repository.dart';
import '../constants/notifications_api_constants.dart';
import 'local_notifications.dart';
import 'push_messaging.dart';
import '../../../common/core/router/open_chat.dart';

/// S19 / S20 outside the app: local system notifications (always) and
/// Firebase push (once Firebase is configured).
///
/// * [init] (from `main`) sets up both and remembers a notification tap
///   that launched the app.
/// * [onHomeShown] (from Home) asks for notification permission once per
///   device, registers this device's push token and opens a pending tap.
///   Nothing is asked during sign-up.
/// * [onSignOut] (before the session is cleared) unregisters the token.
///
/// Taps open live tracking (S19) or the ride summary (S20) on the root
/// navigator, like the in-app banner.
class RideNotifications implements RideAlertNotifier {
  RideNotifications({
    required LocalNotifications local,
    required PushMessaging push,
    required PushTokensRepository tokens,
    required SharedPreferences preferences,
    required bool Function() isSignedIn,
    String? platform,
  }) : _local = local,
       _push = push,
       _tokens = tokens,
       _prefs = preferences,
       _isSignedIn = isSignedIn,
       _platform =
           platform ??
           (defaultTargetPlatform == TargetPlatform.iOS
               ? NotificationsApiConstants.platformIos
               : NotificationsApiConstants.platformAndroid);

  final LocalNotifications _local;
  final PushMessaging _push;
  final PushTokensRepository _tokens;
  final SharedPreferences _prefs;
  final bool Function() _isSignedIn;
  final String _platform;

  final StreamController<void> _pushReceived =
      StreamController<void>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];

  GlobalKey<NavigatorState>? _navigatorKey;
  bool _ready = false;
  bool _homeReached = false;
  RideAlertPayload? _pending;
  String? _registeredToken;

  /// Set when the backend has no `register_push_token` yet: no retries
  /// for this app session.
  bool _backendMissing = false;

  /// The ride a notification tap is waiting to open (until Home shows).
  @visibleForTesting
  RideAlertPayload? get pending => _pending;

  /// The token last stored with `register_push_token`.
  @visibleForTesting
  String? get registeredToken => _registeredToken;

  @override
  Stream<void> get pushReceived => _pushReceived.stream;

  /// Sets up local notifications and (when configured) Firebase. Never
  /// throws; without Firebase config the app behaves exactly as before.
  Future<void> init({required GlobalKey<NavigatorState> navigatorKey}) async {
    _navigatorKey = navigatorKey;
    try {
      await _local.init(onTap: open);
      _ready = true;
      final launch = await _local.launchPayload();
      if (launch != null) open(launch);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Local notifications unavailable',
        error: error,
        stackTrace: stackTrace,
        tag: 'Notifications',
      );
    }

    if (await _push.init()) {
      _subscriptions
        // In the foreground the in-app banner shows it (no second system
        // notification): just re-read the feed now.
        ..add(_push.onMessage.listen((_) => _pushReceived.add(null)))
        ..add(_push.onMessageOpenedApp.listen(_openData))
        ..add(_push.onTokenRefresh.listen(_onTokenRefresh));
      final initial = await _push.getInitialMessage();
      if (initial != null) _openData(initial);
    }

    // Home may have shown while this was still starting.
    if (_homeReached) await _activate();
  }

  /// Home is on screen with a signed-in user.
  Future<void> onHomeShown() async {
    _homeReached = true;
    await _activate();
  }

  /// Ride Partner reminders go out this long before the pick-up.
  static const Duration reminderLead = Duration(minutes: 30);
  static const String _remindersKey = 'drive_reminders';
  static const String _shownNowKey = 'drive_reminders_shown_now';

  /// Keeps one "You have a ride in 30 min" notification per booked drive
  /// that hasn't started: scheduled for 30 min before the pick-up (or right
  /// away, once, when that time has already passed), and cancelled for
  /// drives that started, were cancelled or are gone.
  Future<void> syncDriveReminders(
    List<DriveReminder> drives, {
    DateTime? now,
  }) async {
    if (!_ready) return;
    final at = now ?? DateTime.now();
    final previous = _prefs.getStringList(_remindersKey) ?? const [];
    final shownNow = {...?_prefs.getStringList(_shownNowKey)};
    final kept = <String>{};
    for (final d in drives) {
      if (!d.pickupAt.isAfter(at)) continue;
      final remindAt = d.pickupAt.subtract(reminderLead);
      final minutes = d.pickupAt.difference(at).inMinutes.clamp(1, 30);
      if (remindAt.isAfter(at)) {
        await _local.scheduleRideReminder(
          requestId: d.requestId,
          at: remindAt,
          title: 'Ride in 30 minutes 🚗',
          body: d.body,
        );
      } else if (!shownNow.contains(d.requestId)) {
        // Booked late, or the app was closed: remind now, once.
        shownNow.add(d.requestId);
        await _local.scheduleRideReminder(
          requestId: d.requestId,
          at: at.add(const Duration(seconds: 2)),
          title: 'Ride in $minutes minutes 🚗',
          body: d.body,
        );
      }
      kept.add(d.requestId);
    }
    for (final id in previous) {
      if (!kept.contains(id)) await _local.cancelRideReminder(id);
    }
    await _prefs.setStringList(_remindersKey, kept.toList());
    await _prefs.setStringList(
      _shownNowKey,
      shownNow.where(kept.contains).toList(),
    );
  }

  /// Call before the session is cleared: forgets this device's push token
  /// on the backend (best effort) and drops pending navigation.
  Future<void> onSignOut() async {
    _homeReached = false;
    _pending = null;
    // No reminders for the next account.
    if (_ready) await syncDriveReminders(const []);
    final token = _registeredToken;
    _registeredToken = null;
    if (token == null || _backendMissing) return;
    try {
      await _tokens.unregister(token).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Best effort: the server also drops tokens FCM reports as invalid.
    }
  }

  @override
  Future<void> show(RideAlert alert) async {
    if (!_ready) return;
    await _local.showRideAlert(alert);
  }

  /// Opens the ride for a tapped notification, or keeps it until Home is
  /// on screen (cold start, still signing in).
  void open(RideAlertPayload payload) {
    final navigator = _navigatorKey?.currentState;
    if (!_homeReached || navigator == null) {
      _pending = payload;
      return;
    }
    openOverHome(navigator, payload.route, arguments: payload.arguments);
  }

  void _openData(Map<String, dynamic> data) {
    final payload = RideAlertPayload.fromData(data);
    if (payload != null) open(payload);
  }

  Future<void> _activate() async {
    if (!_homeReached) return;
    final pending = _pending;
    if (pending != null) {
      _pending = null;
      open(pending);
    }
    if (_ready) await _askPermissionOnce();
    await registerPushToken();
  }

  Future<void> _askPermissionOnce() async {
    if (_prefs.getBool(NotificationsApiConstants.permissionAskedKey) ?? false) {
      return;
    }
    await _prefs.setBool(NotificationsApiConstants.permissionAskedKey, true);
    try {
      await _local.requestPermission();
      // Same OS permission: no second prompt; lets FCM know the answer.
      if (_push.isAvailable) await _push.requestPermission();
    } catch (error) {
      AppLogger.warning('Permission request failed: $error', tag: 'Push');
    }
  }

  /// Stores this device's FCM token for the signed-in user. Skipped when
  /// Firebase isn't configured, nobody is signed in, or the backend has no
  /// `register_push_token` yet; failures are silent.
  @visibleForTesting
  Future<void> registerPushToken([String? token]) async {
    if (!_push.isAvailable || _backendMissing || !_isSignedIn()) return;
    final value = token ?? await _push.getToken();
    if (value == null || value == _registeredToken) return;
    final result = await _tokens.register(token: value, platform: _platform);
    result.match((_) {}, (stored) {
      if (stored) {
        _registeredToken = value;
      } else {
        _backendMissing = true;
      }
    });
  }

  void _onTokenRefresh(String token) {
    if (_homeReached) unawaited(registerPushToken(token));
  }
}

/// A booked drive (the user is the Ride Partner) that hasn't started.
class DriveReminder {
  const DriveReminder({
    required this.requestId,
    required this.pickupAt,
    required this.kids,
    required this.destination,
  });

  final String requestId;
  final DateTime pickupAt;

  /// "Emma", "Emma & Noah".
  final String kids;
  final String destination;

  /// "Pick up Emma at 8:00 AM for Doon Public School. Please make sure you
  /// start the ride."
  String get body {
    final t = pickupAt.toLocal();
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final clock = '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
    return 'Pick up $kids at $clock for $destination. Please make sure you '
        'start the ride.';
  }
}
