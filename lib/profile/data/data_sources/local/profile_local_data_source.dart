import 'package:shared_preferences/shared_preferences.dart';

import '../../../../common/core/constants/app_constants.dart';
import '../../../../common/core/error/exceptions.dart';
import '../../../domain/entities/ride_mode.dart';

/// Ride mode chosen on About you; the backend has no column for it.
/// Throws `CacheException` on write failures.
abstract interface class ProfileLocalDataSource {
  RideMode getRideMode();

  Future<void> saveRideMode(RideMode mode);
}

class ProfileLocalDataSourceImpl implements ProfileLocalDataSource {
  const ProfileLocalDataSourceImpl(this._preferences);

  final SharedPreferences _preferences;

  @override
  RideMode getRideMode() =>
      RideMode.parse(_preferences.getString(AppConstants.cacheKeyRideRole));

  @override
  Future<void> saveRideMode(RideMode mode) async {
    final ok = await _preferences.setString(
      AppConstants.cacheKeyRideRole,
      mode.name,
    );
    if (!ok) throw const CacheException('We couldn’t save your choice.');
  }
}
