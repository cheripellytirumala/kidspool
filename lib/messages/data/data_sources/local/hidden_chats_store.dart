import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/ride_chat.dart';

/// One-to-one ride chats the user deleted ("Delete chat"), saved on this
/// device. A deleted chat stays hidden until the other parent writes again:
/// a message newer than the deletion brings it back.
class HiddenChatsStore {
  HiddenChatsStore(this._preferences);

  final SharedPreferences _preferences;

  static const String _key = 'hidden_ride_chats';

  static String keyOf(String requestId, String driverId) =>
      '$requestId|$driverId';

  Map<String, DateTime> _read() {
    final raw = _preferences.getString(_key);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries) e.key: ?DateTime.tryParse('${e.value}'),
      };
    } on FormatException {
      return {};
    }
  }

  /// Hides the chat (request, Ride Partner) from now on.
  Future<void> hide(String requestId, String driverId, {DateTime? at}) async {
    final map = _read()
      ..[keyOf(requestId, driverId)] = (at ?? DateTime.now()).toUtc();
    await _preferences.setString(
      _key,
      jsonEncode({
        for (final e in map.entries) e.key: e.value.toIso8601String(),
      }),
    );
  }

  /// Deleted, and nothing new has been said since.
  bool isHidden(RideChat chat) {
    final hiddenAt = _read()[keyOf(chat.requestId, chat.driverId)];
    if (hiddenAt == null) return false;
    final last = chat.lastAt;
    return last == null || !last.toUtc().isAfter(hiddenAt);
  }
}
