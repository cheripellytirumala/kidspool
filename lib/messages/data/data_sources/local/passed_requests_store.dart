import 'package:shared_preferences/shared_preferences.dart';

/// Ride requests a Ride Partner answered "Not this time", saved on this
/// device per signed-in parent so they stay gone after the app restarts.
/// The server has no "pass" yet, so a reinstall brings them back.
class PassedRequestsStore {
  PassedRequestsStore(this._preferences);

  final SharedPreferences _preferences;

  /// Older ids are dropped past this many (requests expire anyway).
  static const int maxKept = 500;

  static String _key(String userId) => 'passed_ride_requests_$userId';

  Set<String> read(String? userId) {
    if (userId == null) return {};
    return {...?_preferences.getStringList(_key(userId))};
  }

  Future<void> add(String? userId, String requestId) async {
    if (userId == null) return;
    final ids = [...?_preferences.getStringList(_key(userId))]
      ..remove(requestId);
    ids.add(requestId);
    final kept = ids.length > maxKept ? ids.sublist(ids.length - maxKept) : ids;
    await _preferences.setStringList(_key(userId), kept);
  }
}
