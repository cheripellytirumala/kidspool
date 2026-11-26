import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../common/core/usecase/usecase.dart';
import '../../core/constants/home_api_constants.dart';
import '../../domain/usecases/get_driver_available.dart';
import '../../domain/usecases/set_driver_available.dart';

/// The Ride Partner's "Available" switch on Home.
///
/// * On app open (and back in the foreground) the switch shows the
///   server's state, so it matches the green dot other parents see, also
///   when it was switched on another phone.
/// * Once on, it stays on in the foreground and in the background until
///   the driver switches it off, signs out, or the app is closed.
/// * While on, the server is reminded every
///   [HomeApiConstants.availabilityHeartbeat] and whenever the app comes
///   back to the foreground. A killed app can't always say goodbye, so the
///   server also counts an "on" it hasn't heard about for a while as off.
class DriverAvailabilityProvider extends ChangeNotifier
    with WidgetsBindingObserver {
  DriverAvailabilityProvider({
    required SetDriverAvailable setDriverAvailable,
    GetDriverAvailable? getDriverAvailable,
    this.heartbeat = HomeApiConstants.availabilityHeartbeat,
    WidgetsBinding? binding,
  }) : _set = setDriverAvailable,
       _get = getDriverAvailable,
       _binding = binding;

  final SetDriverAvailable _set;
  final GetDriverAvailable? _get;
  bool _isDriver = false;
  final Duration heartbeat;
  final WidgetsBinding? _binding;

  bool _available = false;
  bool _busy = false;
  bool _started = false;
  bool _disposed = false;
  Timer? _timer;

  bool get available => _available;

  /// A switch change is on its way to the server.
  bool get busy => _busy;

  WidgetsBinding get _wb => _binding ?? WidgetsBinding.instance;

  /// Home was shown. The first call of this launch reads the server's
  /// state; a user who no longer gives rides is switched off.
  Future<void> sync({required bool isDriver}) async {
    _isDriver = isDriver;
    if (!_started) {
      _started = true;
      _wb.addObserver(this);
      if (isDriver) await _refresh();
    }
    if (!isDriver && _available) await setAvailable(false);
  }

  /// Takes the server's value. Still on → "still on" ping and heartbeat;
  /// no answer → the switch keeps what it shows.
  Future<void> _refresh() async {
    final get = _get;
    if (get == null || _busy) return;
    final result = await get(const NoParams());
    if (_busy || _disposed) return;
    result.match((_) {}, (serverOn) {
      if (serverOn != _available) {
        _available = serverOn;
        _notify();
      }
      _ping();
      _restartHeartbeat();
    });
  }

  /// Returns an error message to show, or null.
  Future<String?> setAvailable(bool value) async {
    if (_busy || value == _available) return null;
    _busy = true;
    _available = value;
    _notify();
    final result = await _set(value);
    _busy = false;
    return result.match(
      (f) {
        _available = !value;
        _notify();
        return f.message;
      },
      (serverValue) {
        _available = serverValue;
        _restartHeartbeat();
        _notify();
        return null;
      },
    );
  }

  /// Before signing out: off for this account.
  Future<void> turnOff() async {
    _timer?.cancel();
    if (_available) {
      _available = false;
      _notify();
      await _set(false);
    }
  }

  void _restartHeartbeat() {
    _timer?.cancel();
    if (!_available) return;
    _timer = Timer.periodic(heartbeat, (_) => _ping());
  }

  void _ping() {
    if (_available) _set(true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Back in the foreground: take the server's state (another phone
        // may have changed it); still on → ping.
        if (_get != null && _isDriver) {
          _refresh();
        } else {
          _ping();
          _restartHeartbeat();
        }
      case AppLifecycleState.detached:
        // The app is closing: best effort, the next launch starts off anyway.
        if (_available) {
          _available = false;
          _timer?.cancel();
          _set(false);
        }
      case AppLifecycleState.inactive ||
          AppLifecycleState.hidden ||
          AppLifecycleState.paused:
        // Background: stays on.
        break;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_started) _wb.removeObserver(this);
    super.dispose();
  }
}
