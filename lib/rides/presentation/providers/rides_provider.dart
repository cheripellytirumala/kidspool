import 'package:flutter/foundation.dart';

import '../../../common/core/usecase/usecase.dart';
import '../../../messages/core/constants/messages_api_constants.dart';
import '../../../messages/domain/entities/ride_request.dart';
import '../../../messages/domain/usecases/get_my_rides.dart';
import '../../../messages/domain/usecases/get_requests_inbox.dart';
import '../../../profile/domain/entities/ride_mode.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../profile/domain/usecases/change_ride_mode.dart';

enum RidesTab { requests, upcoming, past }

/// One tab's rows, or why they couldn't load.
class RidesTabState {
  const RidesTabState({this.items = const [], this.error, this.loaded = false});

  final List<RideRequest> items;
  final String? error;
  final bool loaded;
}

/// F19c · Your rides: requests to help (as a Ride Partner), upcoming rides
/// (asked for or driving) and history.
class RidesProvider extends ChangeNotifier {
  RidesProvider({
    required GetRequestsInbox getRequestsInbox,
    required GetMyRides getMyRides,
    required ProfileRepository profile,
    required ChangeRideMode changeRideMode,
  }) : _getRequestsInbox = getRequestsInbox,
       _getMyRides = getMyRides,
       _profile = profile,
       _changeRideMode = changeRideMode {
    _available = _profile.getRideMode() == RideMode.both;
    _tab = _available ? RidesTab.requests : RidesTab.upcoming;
  }

  final GetRequestsInbox _getRequestsInbox;
  final GetMyRides _getMyRides;
  final ProfileRepository _profile;
  final ChangeRideMode _changeRideMode;

  late RidesTab _tab;
  late bool _available;
  bool _loading = false;
  bool _disposed = false;
  final Map<RidesTab, RidesTabState> _tabs = {
    for (final t in RidesTab.values) t: const RidesTabState(),
  };

  RidesTab get tab => _tab;

  /// "Available to help families near you" (get & give rides).
  bool get available => _available;
  bool get isLoading => _loading && !_tabs[_tab]!.loaded;

  RidesTabState stateOf(RidesTab tab) => _tabs[tab]!;
  RidesTabState get current => _tabs[_tab]!;

  /// Shown next to Requests / Upcoming once loaded.
  int? countOf(RidesTab tab) {
    final s = _tabs[tab]!;
    if (tab == RidesTab.past || !s.loaded || s.error != null) return null;
    if (tab == RidesTab.requests && !_available) return null;
    return s.items.length;
  }

  void selectTab(RidesTab tab) {
    if (tab == _tab) return;
    _tab = tab;
    _notify();
  }

  /// [silent]: background refresh, no spinner.
  Future<void> load({bool silent = false}) async {
    if (silent && _loading) return;
    if (!silent) {
      _loading = true;
      _notify();
    }
    await Future.wait([
      _loadRequests(),
      _loadRides(RidesTab.upcoming, MessagesApiConstants.scopeUpcoming),
      _loadRides(RidesTab.past, MessagesApiConstants.scopePast),
    ]);
    _loading = false;
    _notify();
  }

  Future<void> _loadRequests() async {
    if (!_available) {
      _tabs[RidesTab.requests] = const RidesTabState(loaded: true);
      return;
    }
    final result = await _getRequestsInbox(const NoParams());
    _tabs[RidesTab.requests] = result.match(
      (f) => RidesTabState(error: f.message, loaded: true),
      // Requests sent to me that I haven't answered yet come first.
      (inbox) => RidesTabState(
        items: [
          ...inbox.incoming.where((r) => !r.offered),
          ...inbox.incoming.where((r) => r.offered),
        ],
        loaded: true,
      ),
    );
  }

  Future<void> _loadRides(RidesTab tab, String scope) async {
    final result = await _getMyRides(scope);
    _tabs[tab] = result.match(
      (f) => RidesTabState(error: f.message, loaded: true),
      (items) => RidesTabState(items: items, loaded: true),
    );
  }

  /// Returns an error message to show, if any.
  Future<String?> setAvailable(bool value) async {
    if (value == _available) return null;
    _available = value;
    _notify();
    final result = await _changeRideMode(
      value ? RideMode.both : RideMode.seeker,
    );
    return result.match(
      (f) {
        _available = !value;
        _notify();
        return f.message;
      },
      (_) {
        _loading = true;
        _notify();
        _loadRequests().whenComplete(() {
          _loading = false;
          _notify();
        });
        return null;
      },
    );
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
