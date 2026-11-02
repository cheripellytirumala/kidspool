import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supabase Auth session returned by the `verify-otp` Edge Function and
/// renewed with the refresh token.
class AuthSession extends Equatable {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.userId,
  });

  final String accessToken;
  final String refreshToken;

  /// Expiry of [accessToken] in seconds since epoch.
  final int expiresAt;
  final String? userId;

  /// True when the access token expires within [margin].
  bool isExpiring({Duration margin = const Duration(seconds: 60)}) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expiresAt - margin.inSeconds <= now;
  }

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt,
    'userId': userId,
  };

  static AuthSession? tryParse(Map<String, dynamic> json) {
    final access = json['accessToken'];
    final refresh = json['refreshToken'];
    final expiresAt = json['expiresAt'];
    if (access is! String || refresh is! String || expiresAt is! num) {
      return null;
    }
    return AuthSession(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expiresAt.toInt(),
      userId: json['userId'] as String?,
    );
  }

  @override
  List<Object?> get props => [accessToken, refreshToken, expiresAt, userId];
}

/// Holds the current [AuthSession] used by [AuthInterceptor].
abstract interface class AuthTokenProvider {
  AuthSession? get session;

  bool get hasSession;

  Future<void> saveSession(AuthSession session);

  Future<void> clear();
}

/// Session kept in memory only (tests).
class InMemoryAuthTokenProvider implements AuthTokenProvider {
  AuthSession? _session;

  @override
  AuthSession? get session => _session;

  @override
  bool get hasSession => _session != null;

  @override
  Future<void> saveSession(AuthSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}

/// Session persisted in [SharedPreferences] so the user stays signed in.
///
/// Consider `flutter_secure_storage` before release: shared preferences are
/// not encrypted at rest.
class PrefsAuthTokenProvider implements AuthTokenProvider {
  PrefsAuthTokenProvider(this._preferences) {
    final raw = _preferences.getString(_key);
    if (raw == null) return;
    try {
      _session = AuthSession.tryParse(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      _session = null;
    }
  }

  static const _key = 'auth_session';

  final SharedPreferences _preferences;
  AuthSession? _session;

  @override
  AuthSession? get session => _session;

  @override
  bool get hasSession => _session != null;

  @override
  Future<void> saveSession(AuthSession session) async {
    _session = session;
    await _preferences.setString(_key, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() async {
    _session = null;
    await _preferences.remove(_key);
  }
}
