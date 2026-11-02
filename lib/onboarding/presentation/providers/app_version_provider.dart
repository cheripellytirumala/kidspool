import 'package:flutter/foundation.dart';

import '../../../common/core/constants/app_constants.dart';
import '../../../common/core/error/failures.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/core/router/onboarding_route.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../domain/entities/app_version.dart';
import '../../../common/domain/repositories/account_repository.dart';
import '../../domain/usecases/get_app_version.dart';

/// S01 launch logic: checks the app version (`check_app_version`), then
/// decides where to go — sign-in, or back into onboarding / Home for a
/// stored session (`get_my_status`). Holds no networking or parsing logic.
class AppVersionProvider extends ChangeNotifier {
  AppVersionProvider({
    required GetAppVersion getAppVersion,
    required AccountRepository account,
  }) : _getAppVersion = getAppVersion,
       _account = account;

  final GetAppVersion _getAppVersion;
  final AccountRepository _account;

  ViewStatus _status = ViewStatus.initial;
  AppVersion? _appVersion;
  Failure? _failure;
  String _nextRoute = AppRoutes.phoneNumber;

  ViewStatus get status => _status;
  bool get isLoading => _status.isLoading;
  AppVersion? get appVersion => _appVersion;
  String? get errorMessage => _failure?.message;
  Failure? get failure => _failure;

  /// True when `check_app_version` says this build must be updated.
  bool get isUpdateRequired => _appVersion?.isUpdateRequired ?? false;

  /// Route to open once [status] is success and no update is required.
  String get nextRoute => _nextRoute;

  Future<void> fetchAppVersion({
    String versionNumber = AppConstants.appVersionNumber,
  }) async {
    if (_status.isLoading) return;
    _setStatus(ViewStatus.loading);

    final result = await _getAppVersion(
      GetAppVersionParams(platform: _currentDevice, appVersion: versionNumber),
    );

    final failure = result.getLeft().toNullable();
    if (failure != null) {
      _failure = failure;
      return _setStatus(ViewStatus.failure);
    }
    _appVersion = result.getRight().toNullable();
    _failure = null;
    if (!isUpdateRequired) _nextRoute = await _resolveStartRoute();
    _setStatus(ViewStatus.success);
  }

  Future<String> _resolveStartRoute() async {
    if (!_account.isSignedIn) return AppRoutes.phoneNumber;
    final status = await _account.getMyStatus();
    return status.match((failure) {
      // Session gone (expired refresh token, deleted user): sign in again.
      if (failure is UnauthorizedFailure || failure.statusCode == 404) {
        _account.signOut();
      }
      return AppRoutes.phoneNumber;
    }, OnboardingRoute.of);
  }

  String get _currentDevice => defaultTargetPlatform == TargetPlatform.iOS
      ? AppConstants.deviceIos
      : AppConstants.deviceAndroid;

  bool _disposed = false;

  void _setStatus(ViewStatus status) {
    _status = status;
    // The version check can finish after the splash has been closed.
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
