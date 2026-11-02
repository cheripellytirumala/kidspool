import 'package:flutter/foundation.dart';

import '../../../common/presentation/state/view_state.dart';
import '../../domain/entities/ride_tracking.dart';
import '../../domain/usecases/get_ride_tracking.dart';
import '../../domain/usecases/say_thank_you.dart';

/// F23 · Ride completed — one `get_ride_tracking` read, plus "Say thank you"
/// (`rate_ride`) for the requesting parent.
class RideCompletedProvider extends ChangeNotifier {
  RideCompletedProvider({
    required GetRideTracking getRideTracking,
    required SayThankYou sayThankYou,
  }) : _getRideTracking = getRideTracking,
       _sayThankYou = sayThankYou;

  final GetRideTracking _getRideTracking;
  final SayThankYou _sayThankYou;

  String? _requestId;
  RideTracking? _tracking;
  ViewStatus _status = ViewStatus.initial;
  String? _errorMessage;
  bool _thanking = false;
  bool _thanked = false;
  bool _disposed = false;

  RideTracking? get tracking => _tracking;
  ViewStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get hasRide => _requestId != null;
  bool get thanking => _thanking;

  /// Thanks already sent (now or earlier).
  bool get thanked => _thanked || (_tracking?.rated ?? false);

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

  /// Returns an error message, or null when the thanks went out.
  Future<String?> sayThankYou(int rating) async {
    final id = _requestId;
    if (id == null || _thanking || thanked) return null;
    _thanking = true;
    _notify();
    final result = await _sayThankYou(SayThankYouParams(id, rating: rating));
    _thanking = false;
    final failure = result.getLeft().toNullable();
    if (failure == null || failure.code == 'already_rated') _thanked = true;
    _notify();
    return failure?.message;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
