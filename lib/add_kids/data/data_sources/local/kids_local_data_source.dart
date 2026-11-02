import 'package:shared_preferences/shared_preferences.dart';

/// Throws `CacheException` on read/write failures.
abstract interface class KidsLocalDataSource {}

class KidsLocalDataSourceImpl implements KidsLocalDataSource {
  const KidsLocalDataSourceImpl(this._preferences);

  // ignore: unused_field
  final SharedPreferences _preferences;
}
