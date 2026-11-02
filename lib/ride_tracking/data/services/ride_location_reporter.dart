import 'dart:async';

import '../../../common/core/error/exceptions.dart';
import '../../../common/core/utils/logger.dart';
import '../../core/constants/ride_tracking_api_constants.dart';
import '../../domain/repositories/ride_location_sharing.dart';
import '../data_sources/local/ride_location_data_source.dart';
import '../data_sources/remote/ride_tracking_error_messages.dart';
import '../data_sources/remote/ride_tracking_remote_data_source.dart';
import '../models/ride_fix.dart';

/// Sends the Ride Partner's position with `update_ride_location` from
/// `start_ride` until `complete_ride`, at most every
/// [RideTrackingApiConstants.locationInterval] (10 s, as in the previous
/// app). A move that came in sooner goes out on the next tick, so the
/// parent's map never lags more than that. Foreground only: the app has no
/// background-location setup.
class RideLocationReporter implements RideLocationSharing {
  RideLocationReporter({
    required RideLocationDataSource location,
    required RideTrackingRemoteDataSource tracking,
  }) : _location = location,
       _tracking = tracking;

  final RideLocationDataSource _location;
  final RideTrackingRemoteDataSource _tracking;

  static const Duration interval = RideTrackingApiConstants.locationInterval;

  String? _requestId;
  StreamSubscription<RideFix>? _fixes;
  Timer? _flush;
  RideFix? _pending;
  DateTime? _lastSent;
  bool _sending = false;

  @override
  String? get requestId => _requestId;

  @override
  void start(String requestId) {
    if (_requestId == requestId) return;
    stop();
    _requestId = requestId;
    AppLogger.debug('sharing location for $requestId', tag: 'Tracking');
    _fixes = _location.fixes().listen(
      (fix) {
        _pending = fix;
        final last = _lastSent;
        if (last == null || DateTime.now().difference(last) >= interval) {
          _send();
        }
      },
      onError: (Object e) => AppLogger.debug('GPS error: $e', tag: 'Tracking'),
    );
    _flush = Timer.periodic(interval, (_) => _send());
  }

  @override
  void stop() {
    if (_requestId != null) {
      AppLogger.debug('stopped $_requestId', tag: 'Tracking');
    }
    _fixes?.cancel();
    _flush?.cancel();
    _fixes = null;
    _flush = null;
    _pending = null;
    _lastSent = null;
    _requestId = null;
  }

  Future<void> _send() async {
    final id = _requestId;
    final fix = _pending;
    if (id == null || fix == null || _sending) return;
    _sending = true;
    _pending = null;
    try {
      await _tracking.updateLocation(id, fix);
      _lastSent = DateTime.now();
    } on ServerException catch (e) {
      if (RideTrackingErrorMessages.notActiveCodes.contains(e.code)) {
        // Finished, cancelled or taken over elsewhere: nothing to share.
        if (_requestId == id) stop();
      } else {
        _pending ??= fix;
      }
    } catch (e) {
      // Offline for a moment: retry this fix unless a newer one came in.
      AppLogger.debug('update failed: $e', tag: 'Tracking');
      _pending ??= fix;
    } finally {
      _sending = false;
    }
  }
}
