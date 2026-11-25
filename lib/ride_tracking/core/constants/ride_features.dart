/// On/off switches for ride-day features. Flip a value and rebuild.
abstract final class RideFeatures {
  /// Ride Partner side: ask for the parent's 4-digit pick-up PIN when they
  /// tap "Picked up".
  ///
  ///   true  → the PIN dialog shows (enter it or skip).
  ///   false → no dialog; "Picked up" goes straight through.
  ///
  /// Parents always see the PIN (live screen + "has arrived" notification)
  /// either way. If the server's `require_pickup_pin` is ever set to 1, the
  /// dialog shows regardless, so pick-ups are never blocked.
  static const bool driverPickupPin = false;
}
