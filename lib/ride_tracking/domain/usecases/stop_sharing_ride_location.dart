import '../repositories/ride_location_sharing.dart';

/// Ride Partner: stops sending GPS positions (ride over).
class StopSharingRideLocation {
  const StopSharingRideLocation(this._sharing);

  final RideLocationSharing _sharing;

  /// Stops only when [requestId] is the ride being shared.
  void call(String requestId) {
    if (_sharing.requestId == requestId) _sharing.stop();
  }
}
