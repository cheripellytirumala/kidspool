import 'package:shared_preferences/shared_preferences.dart';

import '../../../../common/core/error/exceptions.dart';
import '../../../core/constants/home_api_constants.dart';

/// Throws `CacheException` on read/write failures.
abstract interface class HomeLocalDataSource {
  /// Newest notification time the user has seen on the bell.
  DateTime? getNotificationsSeenAt();

  Future<void> setNotificationsSeenAt(DateTime at);
}

class HomeLocalDataSourceImpl implements HomeLocalDataSource {
  const HomeLocalDataSourceImpl(this._preferences);

  final SharedPreferences _preferences;

  @override
  DateTime? getNotificationsSeenAt() {
    final value = _preferences.getString(
      HomeApiConstants.notificationsSeenAtKey,
    );
    return value == null ? null : DateTime.tryParse(value);
  }

  @override
  Future<void> setNotificationsSeenAt(DateTime at) async {
    final ok = await _preferences.setString(
      HomeApiConstants.notificationsSeenAtKey,
      at.toUtc().toIso8601String(),
    );
    if (!ok) throw const CacheException();
  }
}
