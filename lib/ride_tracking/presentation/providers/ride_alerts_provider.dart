import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../common/core/usecase/usecase.dart';
import '../../core/constants/ride_tracking_api_constants.dart';
import '../../domain/entities/ride_alert.dart';
import '../../domain/usecases/get_ride_alerts.dart';

/// S19 / S20 in-app banners: polls `get_my_notifications` while the app is
/// in the foreground and someone is signed in, and queues ride alerts that
/// arrived since the last look.
class RideAlertsProvider extends ChangeNotifier {
  RideAlertsProvider({
    required GetRideAlerts getRideAlerts,
    this.pollInterval = RideTrackingApiConstants.alertsPollInterval,
    DateTime Function()? clock,
  }) : _getRideAlerts = getRideAlerts,
       _clock = clock ?? DateTime.now;

  final GetRideAlerts _getRideAlerts;
  final Duration pollInterval;
  final DateTime Function() _clock;

  final Set<String> _seen = {};
  final List<RideAlert> _queue = [];
  Timer? _poll;
  bool _inFlight = false;
  bool _running = false;
  bool _disposed = false;

  /// Set when the server has no `get_my_notifications` (PostgREST 404):
  /// polling stops for this app session instead of failing every interval.
  bool _unavailable = false;

  /// The alert on screen, if any.
  RideAlert? get current => _queue.isEmpty ? null : _queue.first;

  /// Starts (or resumes) polling: checks now, then every [pollInterval].
  void start() {
    if (_running || _disposed || _unavailable) return;
    _running = true;
    unawaited(check());
    _poll = Timer.periodic(pollInterval, (_) => check());
  }

  /// Stops polling (app in the background).
  void stop() {
    _running = false;
    _poll?.cancel();
    _poll = null;
  }

  Future<void> check() async {
    if (_inFlight || _disposed || _unavailable || !_getRideAlerts.canFetch) {
      return;
    }
    _inFlight = true;
    final result = await _getRideAlerts(const NoParams());
    _inFlight = false;
    if (_disposed) return;
    if (result.getLeft().toNullable()?.statusCode == 404) {
      // The RPC isn't deployed on this backend yet.
      _unavailable = true;
      stop();
      return;
    }
    final alerts = result.getRight().toNullable();
    if (alerts == null) return;
    final freshSince = _clock().subtract(
      RideTrackingApiConstants.alertFreshness,
    );
    final added = <RideAlert>[];
    // Oldest first, so the queue reads in order.
    for (final alert in alerts.reversed) {
      if (!_seen.add(alert.id)) continue;
      if (alert.createdAt.isAfter(freshSince)) added.add(alert);
    }
    if (added.isEmpty) return;
    _queue.addAll(added);
    notifyListeners();
  }

  /// Hides [current] and moves on to the next queued alert.
  void dismiss() {
    if (_queue.isEmpty) return;
    _queue.removeAt(0);
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
