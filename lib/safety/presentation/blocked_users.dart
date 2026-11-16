import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../common/core/error/failures.dart';
import '../core/safety_api_constants.dart';
import '../data/safety_repository.dart';
import '../domain/safety_entities.dart';

/// The people the signed-in user blocked. Screens hide their messages and
/// family cards ([isBlocked]); Profile lists them with Unblock.
///
/// Kept on the device per user (so hiding is instant and works offline)
/// and synced with `get_my_blocks` on [load].
class BlockedUsers extends ChangeNotifier {
  BlockedUsers({
    required SafetyRepository repository,
    required SharedPreferences preferences,
    required String? Function() userId,
  }) : _repository = repository,
       _preferences = preferences,
       _userId = userId;

  final SafetyRepository _repository;
  final SharedPreferences _preferences;
  final String? Function() _userId;

  String? _loadedFor;
  List<BlockedUser> _users = const [];

  /// Bumped on every local block / unblock, so a server reload that
  /// started earlier doesn't overwrite a newer change.
  int _version = 0;

  /// Block / unblock requests still on their way to the server.
  int _inFlight = 0;

  List<BlockedUser> get users {
    _restore();
    return _users;
  }

  bool isBlocked(String? userId) {
    if (userId == null) return false;
    _restore();
    return _users.any((u) => u.id == userId);
  }

  /// Reads this user's cached list (once per signed-in account).
  void _restore() {
    final me = _userId();
    if (me == _loadedFor) return;
    _loadedFor = me;
    _users = const [];
    if (me == null) return;
    // First use for this account: also sync from the server.
    Future.microtask(load);
    final raw = _preferences.getString(SafetyApiConstants.blocksCacheKey(me));
    if (raw == null) return;
    try {
      _users = [
        for (final item in jsonDecode(raw) as List<dynamic>)
          if (item is Map<String, dynamic>) BlockedUser.fromJson(item),
      ];
    } on FormatException {
      _users = const [];
    }
  }

  Future<void> _save() async {
    final me = _userId();
    if (me == null) return;
    await _preferences.setString(
      SafetyApiConstants.blocksCacheKey(me),
      jsonEncode([for (final u in _users) u.toJson()]),
    );
  }

  /// Refreshes from the server (keeps the cache if that fails).
  Future<void> load() async {
    _restore();
    final version = _version;
    final result = await _repository.blocks();
    // Blocked / unblocked meanwhile (or still sending): keep the newer
    // local list.
    if (version != _version || _inFlight > 0) return;
    result.match((_) {}, (list) {
      _users = list;
      _save();
      notifyListeners();
    });
  }

  /// Adds [user] here right away, then on the server. Returns an error
  /// message, or null. If the server isn't ready the block stays on this
  /// device.
  Future<String?> block(BlockedUser user) async {
    _restore();
    if (!_users.any((u) => u.id == user.id)) {
      _version++;
      _users = [user, ..._users];
      await _save();
      notifyListeners();
    }
    _inFlight++;
    final result = await _repository.block(user.id);
    _inFlight--;
    return result.match((f) => _isMissing(f) ? null : f.message, (_) => null);
  }

  /// Marks [user] blocked locally (the server already did it, e.g. via
  /// "Report and block").
  Future<void> markBlocked(BlockedUser user) async {
    _restore();
    if (_users.any((u) => u.id == user.id)) return;
    _version++;
    _users = [user, ..._users];
    await _save();
    notifyListeners();
  }

  Future<String?> unblock(String userId) async {
    _restore();
    _inFlight++;
    final result = await _repository.unblock(userId);
    _inFlight--;
    final error = result.match(
      (f) => _isMissing(f) ? null : f.message,
      (_) => null,
    );
    if (error != null) return error;
    _version++;
    _users = [
      for (final u in _users)
        if (u.id != userId) u,
    ];
    await _save();
    notifyListeners();
    return null;
  }

  /// The SQL isn't applied yet: blocking still works on this device.
  static bool _isMissing(Failure f) =>
      f.code == SafetyApiConstants.functionNotFound;
}
