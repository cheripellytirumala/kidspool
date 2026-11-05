import 'package:flutter/foundation.dart';

import '../../../common/core/router/onboarding_route.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../../common/domain/entities/my_status.dart';
import '../../../common/domain/repositories/account_repository.dart';

/// "We're reviewing your ID": polls `get_my_status` until an admin approves
/// or rejects the identity submission.
class ReviewStatusProvider extends ChangeNotifier {
  ReviewStatusProvider(this._account);

  final AccountRepository _account;

  ViewStatus _status = ViewStatus.initial;
  MyStatus? _myStatus;
  String? _errorMessage;

  bool get isLoading => _status.isLoading;
  String? get errorMessage => _errorMessage;
  bool get isRejected =>
      _myStatus?.onboardingStatus == OnboardingStatus.rejected;
  String? get rejectionReason => _myStatus?.rejectionReason;
  String get firstName => _myStatus?.firstName ?? '';

  /// Reloads the status. Returns the next route once the parent may carry
  /// on (ID re-sent or approved), otherwise `null` (still rejected).
  Future<String?> refresh() async {
    if (_status.isLoading) return null;
    _status = ViewStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _account.getMyStatus();
    return result.match(
      (failure) {
        _status = ViewStatus.failure;
        _errorMessage = failure.message;
        notifyListeners();
        return null;
      },
      (status) {
        _myStatus = status;
        _status = ViewStatus.success;
        notifyListeners();
        final route = OnboardingRoute.of(status);
        return status.hasSubmittedId ? route : null;
      },
    );
  }
}
