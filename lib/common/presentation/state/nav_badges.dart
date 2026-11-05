import 'package:flutter/foundation.dart';

/// Counts shown on the bottom navigation (F24 · the red count on Messages).
///
/// A plain app-wide holder so `AppBottomNav` (common) needn't know about the
/// Messages feature: that feature registers how to recount and pushes fresh
/// totals whenever its own screen loads.
class NavBadges {
  NavBadges._();

  static final NavBadges instance = NavBadges._();

  /// Ride requests to answer + chats with unread messages.
  final ValueNotifier<int> messages = ValueNotifier<int>(0);

  /// Skip network recounts closer together than this (tab switches).
  static const Duration _minInterval = Duration(seconds: 15);

  Future<void> Function()? _recountMessages;
  DateTime? _countedAt;
  Future<void>? _inFlight;

  /// Set once by the Messages feature at start-up.
  void registerMessagesCounter(Future<void> Function() recount) =>
      _recountMessages = recount;

  /// A fresh total from a screen that just loaded the data.
  void setMessages(int count) {
    _countedAt = DateTime.now();
    messages.value = count < 0 ? 0 : count;
  }

  /// Recounts unless a count is recent (or one is already running).
  Future<void> refresh({bool force = false}) {
    final recount = _recountMessages;
    if (recount == null) return Future.value();
    final at = _countedAt;
    if (!force && at != null && DateTime.now().difference(at) < _minInterval) {
      return Future.value();
    }
    return _inFlight ??= recount().whenComplete(() => _inFlight = null);
  }

  /// Signed out: nothing to show for the next account.
  void clear() {
    _countedAt = null;
    messages.value = 0;
  }
}
