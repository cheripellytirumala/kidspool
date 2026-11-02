import '../repositories/ride_location_sharing.dart';

/// Ride Partner: starts sending GPS positions (`update_ride_location`)
/// for the ride in progress.
class StartSharingRideLocation {
  const StartSharingRideLocation(this._sharing);

  final RideLocationSharing _sharing;

  void call(String requestId) => _sharing.start(requestId);
}
