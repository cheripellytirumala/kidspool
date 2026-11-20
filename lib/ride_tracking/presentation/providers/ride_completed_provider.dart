import 'package:flutter/foundation.dart';

import '../../../common/presentation/state/view_state.dart';
import '../../domain/entities/ride_tracking.dart';
import '../../domain/usecases/get_ride_tracking.dart';

/// F23 · Ride completed — one `get_ride_tracking` read. Parents don't rate
/// the Ride Partner.
class RideCompletedProvider extends ChangeNotifier {
  RideCompletedProvider({required GetRideTracking getRideTracking})
    : _getRideTracking = getRideTracking;

  final GetRideTracking _getRideTracking;

  String? _requestId;
  RideTracking? _tracking;
  ViewStatus _status = ViewStatus.initial;
  String? _errorMessage;
  bool _disposed = false;

  RideTracking? get tracking => _tracking;
  ViewStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get hasRide => _requestId != null;

  Future<void> open(String? requestId) async {
    _requestId = requestId;
    if (requestId == null) {
      _status = ViewStatus.failure;
      _errorMessage = 'We couldn’t find this ride. Open it again from Home.';
      _notify();
      return;
    }
    _status = ViewStatus.loading;
    _notify();
    final result = await _getRideTracking(GetRideTrackingParams(requestId));
    if (_disposed) return;
    result.match(
      (failure) {
        _status = ViewStatus.failure;
        _errorMessage = failure.message;
      },
      (tracking) {
        _tracking = tracking;
        _status = ViewStatus.success;
        _errorMessage = null;
      },
    );
    _notify();
  }

  Future<void> retry() => open(_requestId);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
