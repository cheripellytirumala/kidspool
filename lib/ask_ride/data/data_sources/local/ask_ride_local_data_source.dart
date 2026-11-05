import 'package:shared_preferences/shared_preferences.dart';

/// Throws `CacheException` on read/write failures.
///
/// Kids and places now come from the server; kept for future offline
/// caching of the draft.
abstract interface class AskRideLocalDataSource {}

class AskRideLocalDataSourceImpl implements AskRideLocalDataSource {
  const AskRideLocalDataSourceImpl(this._preferences);

  // ignore: unused_field
  final SharedPreferences _preferences;
}
