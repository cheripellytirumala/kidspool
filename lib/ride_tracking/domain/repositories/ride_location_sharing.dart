/// Sends the Ride Partner's GPS position while their ride is in progress.
///
/// One ride at a time; keeps going when the live screen closes and stops
/// by itself once the backend says the ride is over.
abstract interface class RideLocationSharing {
  /// The ride being shared, or null.
  String? get requestId;

  /// Starts sharing for [requestId]; does nothing if it already is.
  void start(String requestId);

  void stop();

  /// The phone's latest GPS position while sharing (fresher than the
  /// server's copy), or null.
  ({double latitude, double longitude})? get lastPosition;
}
