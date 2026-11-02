import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/error/failures.dart';
import '../../core/state/view_state.dart';
import '../../domain/entities/app_version.dart';
import '../../domain/usecases/get_app_version.dart';

/// Exposes app-version state to the UI. Holds no networking or parsing logic.
class AppVersionProvider extends ChangeNotifier {
  AppVersionProvider({required GetAppVersion getAppVersion})
    : _getAppVersion = getAppVersion;

  final GetAppVersion _getAppVersion;

  ViewStatus _status = ViewStatus.initial;
  AppVersion? _appVersion;
  Failure? _failure;

  ViewStatus get status => _status;
  bool get isLoading => _status.isLoading;
  AppVersion? get appVersion => _appVersion;
  String? get errorMessage => _failure?.message;
  Failure? get failure => _failure;

  Future<void> fetchAppVersion({
    int roleId = AppConstants.roleId,
    String versionNumber = AppConstants.appVersionNumber,
  }) async {
    if (_status.isLoading) return;
    _setStatus(ViewStatus.loading);

    final result = await _getAppVersion(
      GetAppVersionParams(
        roleId: roleId,
        device: _currentDevice,
        versionNumber: versionNumber,
      ),
    );

    result.match(
      (failure) {
        _failure = failure;
        _setStatus(ViewStatus.failure);
      },
      (appVersion) {
        _appVersion = appVersion;
        _failure = null;
        _setStatus(ViewStatus.success);
      },
    );
  }

  String get _currentDevice => defaultTargetPlatform == TargetPlatform.iOS
      ? AppConstants.deviceIos
      : AppConstants.deviceAndroid;

  void _setStatus(ViewStatus status) {
    _status = status;
    notifyListeners();
  }
}
