import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../common/core/error/exceptions.dart';
import '../../../core/constants/onboarding_api_constants.dart';
import '../../models/app_version_model.dart';

abstract interface class AppVersionLocalDataSource {
  /// Throws [CacheException] when nothing is cached or the cache is corrupt.
  Future<AppVersionModel> getCachedAppVersion();

  Future<void> cacheAppVersion(AppVersionModel model);
}

class AppVersionLocalDataSourceImpl implements AppVersionLocalDataSource {
  const AppVersionLocalDataSourceImpl(this._preferences);

  final SharedPreferences _preferences;

  @override
  Future<AppVersionModel> getCachedAppVersion() async {
    final raw = _preferences.getString(
      OnboardingApiConstants.cacheKeyAppVersion,
    );
    if (raw == null) throw const CacheException();
    try {
      return AppVersionModel.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      throw const CacheException('Cached app version is corrupt.');
    }
  }

  @override
  Future<void> cacheAppVersion(AppVersionModel model) async {
    final saved = await _preferences.setString(
      OnboardingApiConstants.cacheKeyAppVersion,
      jsonEncode(model.toJson()),
    );
    if (!saved) throw const CacheException('Failed to cache app version.');
  }
}
