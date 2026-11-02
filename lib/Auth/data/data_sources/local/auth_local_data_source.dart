import 'package:shared_preferences/shared_preferences.dart';

/// Throws `CacheException` on read/write failures.
abstract interface class AuthLocalDataSource {}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  const AuthLocalDataSourceImpl(this._preferences);

  // ignore: unused_field
  final SharedPreferences _preferences;
}
