import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../core/constants/ride_tracking_api_constants.dart';
import '../../domain/entities/ride_tracking.dart';
import '../../domain/usecases/complete_ride.dart';
import '../../domain/usecases/get_ride_tracking.dart';
import '../../domain/usecases/mark_picked_up.dart';
import '../../domain/usecases/start_ride.dart';
import '../../domain/usecases/start_sharing_ride_location.dart';
import '../../domain/usecases/stop_sharing_ride_location.dart';
import '../../domain/usecases/trigger_ride_sos.dart';

/// What the Ride Partner can do next on the live screen.
enum DriverRideAction { start, pickedUp, complete }

/// F22 · Live tracking. Polls `get_ride_tracking` every
/// [RideTrackingApiConstants.trackingPollInterval] while the screen is
/// visible ([pause] / [resume] follow the app lifecycle), and keeps the
/// Ride Partner's GPS sharing running while their ride is in progress.
class LiveTrackingProvider extends ChangeNotifier {
  LiveTrackingProvider({
    required GetRideTracking getRideTracking,
    required StartRide startRide,
    required MarkPickedUp markPickedUp,
    required CompleteRide completeRide,
    required TriggerRideSos triggerSos,
    required StartSharingRideLocation startSharing,
    required StopSharingRideLocation stopSharing,
    ({double latitude, double longitude})? Function()? driverPosition,
    this.pollInterval = RideTrackingApiConstants.trackingPollInterval,
  }) : _getRideTracking = getRideTracking,
       _startRide = startRide,
       _markPickedUp = markPickedUp,
       _completeRide = completeRide,
       _triggerSos = triggerSos,
       _startSharing = startSharing,
       _stopSharing = stopSharing,
       _driverPosition = driverPosition;

  /// The Ride Partner's phone GPS (fresher than the server's position).
  final ({double latitude, double longitude})? Function()? _driverPosition;

  /// Auto drop-off was already tried for this ride (once only).
  bool _autoDropTried = false;

  final GetRideTracking _getRideTracking;
  final StartRide _startRide;
  final MarkPickedUp _markPickedUp;
  final CompleteRide _completeRide;
  final TriggerRideSos _triggerSos;
  final StartSharingRideLocation _startSharing;
  final StopSharingRideLocation _stopSharing;
  final Duration pollInterval;

  String? _requestId;
  RideTracking? _tracking;
  ViewStatus _status = ViewStatus.initial;
  String? _errorMessage;
  DriverRideAction? _busyAction;
  bool _sendingSos = false;

  Timer? _poll;
  bool _paused = false;
  bool _inFlight = false;
  bool _needsPath = true;
  bool _disposed = false;

  String? get requestId => _requestId;
  RideTracking? get tracking => _tracking;
  ViewStatus get status => _status;

  /// Why the ride couldn't be shown (no route arguments, network, …).
  String? get errorMessage => _errorMessage;

  /// True when the screen was opened without a ride to show.
  bool get hasRide => _requestId != null;

  DriverRideAction? get busyAction => _busyAction;
  bool get sendingSos => _sendingSos;

  /// The Ride Partner's next step, or null for the requesting parent.
  DriverRideAction? get driverAction {
    final t = _tracking;
    if (t == null || !t.isDriver) return null;
    return switch (t.status) {
      RideTrackingStatus.confirmed => DriverRideAction.start,
      RideTrackingStatus.inProgress =>
        t.pickedUp ? DriverRideAction.complete : DriverRideAction.pickedUp,
      _ => null,
    };
  }

  /// Metres from the car to the drop-off: the phone's own GPS for the Ride
  /// Partner, else the last position on the server. Null when unknown.
  double? get metersToDropoff {
    final t = _tracking;
    final to = t?.destination.point;
    if (t == null || to == null) return null;
    final p = t.isDriver ? _driverPosition?.call() : null;
    final from = p != null
        ? GeoPoint(p.latitude, p.longitude)
        : t.location?.point;
    return from?.metersTo(to);
  }

  /// The car is within [RideTrackingApiConstants.dropoffRadiusMeters] of
  /// the drop-off (or the distance can't be told). The "Dropped off" button
  /// works anywhere; outside this radius the sheet shows the distance left
  /// until it drops off by itself.
  bool get canDropOff {
    if (driverAction != DriverRideAction.complete) return false;
    final m = metersToDropoff;
    return m == null || m <= RideTrackingApiConstants.dropoffRadiusMeters;
  }

  /// Within 100 m of the drop-off with the kids in the car: drop off by
  /// itself (once; the button stays for a retry).
  Future<void> _autoDropOff() async {
    if (_autoDropTried || _busyAction != null) return;
    if (driverAction != DriverRideAction.complete) return;
    final m = metersToDropoff;
    if (m == null || m > RideTrackingApiConstants.dropoffRadiusMeters) return;
    _autoDropTried = true;
    _autoDroppedOff = await runDriverAction() == null;
  }

  bool _autoDroppedOff = false;

  /// The ride was dropped off automatically (the screen says so).
  bool get autoDroppedOff => _autoDroppedOff;

  /// Loads [requestId] and starts polling; null shows the empty state.
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
    await _load();
  }

  Future<void> retry() => open(_requestId);

  /// App went to the background (or the screen is covered).
  void pause() {
    _paused = true;
    _poll?.cancel();
    _poll = null;
    // Driver with the kids aboard: GPS keeps running in the background, so
    // keep checking the 100 m drop-off on the phone (no polling).
    if (driverAction == DriverRideAction.complete) {
      _backgroundCheck ??= Timer.periodic(
        RideTrackingApiConstants.locationInterval,
        (_) => _autoDropOff(),
      );
    }
  }

  Timer? _backgroundCheck;

  /// Back in the foreground: refresh now, then keep polling.
  void resume() {
    _backgroundCheck?.cancel();
    _backgroundCheck = null;
    if (!_paused) return;
    _paused = false;
    if (_tracking != null) unawaited(_load());
    _schedule();
  }

  Future<void> _load() async {
    final id = _requestId;
    if (id == null || _inFlight || _disposed) return;
    _inFlight = true;
    final includePath = _needsPath;
    final result = await _getRideTracking(
      GetRideTrackingParams(id, includePath: includePath),
    );
    _inFlight = false;
    if (_disposed) return;
    result.match(
      (failure) {
        // A failed refresh keeps the last known state on screen.
        if (_tracking == null) {
          _status = ViewStatus.failure;
          _errorMessage = failure.message;
        }
      },
      (fresh) {
        _apply(fresh, includedPath: includePath);
        _status = ViewStatus.success;
        _errorMessage = null;
      },
    );
    _notify();
    _schedule();
    unawaited(_autoDropOff());
  }

  void _apply(RideTracking fresh, {required bool includedPath}) {
    final previous = _tracking;
    var next = fresh;
    if (!includedPath && previous != null) {
      // Polls skip the path: extend the last one with the new position.
      final path = [...previous.path];
      final point = fresh.location?.point;
      if (point != null && (path.isEmpty || path.last != point)) {
        path.add(point);
      }
      next = fresh.copyWith(path: path);
    }
    // Pickup / status changes bring new figures: re-read the path next time.
    _needsPath =
        previous != null &&
        (previous.status != fresh.status ||
            previous.pickedUp != fresh.pickedUp);
    _tracking = next;

    if (next.isDriver) {
      if (next.started) {
        _startSharing(next.requestId);
      } else if (next.completed || next.closed) {
        _stopSharing(next.requestId);
      }
    }
  }

  void _schedule() {
    final t = _tracking;
    final over = t != null && (t.completed || t.closed);
    if (_paused || _disposed || over || _requestId == null) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    _poll ??= Timer.periodic(pollInterval, (_) => _load());
  }

  /// Runs the Ride Partner's [driverAction]. Returns an error message, or
  /// null on success.
  Future<String?> runDriverAction() async {
    final action = driverAction;
    final id = _requestId;
    if (action == null || id == null || _busyAction != null) return null;

    _busyAction = action;
    _notify();
    final Failure? failure = switch (action) {
      DriverRideAction.start => (await _startRide(id)).getLeft().toNullable(),
      DriverRideAction.pickedUp => (await _markPickedUp(
        id,
      )).getLeft().toNullable(),
      DriverRideAction.complete => (await _completeRide(
        id,
      )).getLeft().toNullable(),
    };
    if (_disposed) return failure?.message;
    if (failure == null && action == DriverRideAction.complete) {
      _stopSharing(id);
    }
    _needsPath = true;
    // Show the new state (or the server's truth after an error).
    while (_inFlight) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (_disposed) return failure?.message;
    }
    await _load();
    _busyAction = null;
    _notify();
    return failure?.message;
  }

  /// Raises an SOS on the ride. Returns an error message, or null.
  Future<String?> sendSos() async {
    final id = _requestId;
    if (id == null || _sendingSos) return null;
    _sendingSos = true;
    _notify();
    final result = await _triggerSos(id);
    _sendingSos = false;
    if (!_disposed) {
      _needsPath = true;
      await _load();
    }
    return result.getLeft().toNullable()?.message;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _poll = null;
    _backgroundCheck?.cancel();
    super.dispose();
  }
}
