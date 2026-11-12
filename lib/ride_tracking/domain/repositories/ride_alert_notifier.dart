import '../entities/ride_alert.dart';

/// System-level side of the S19 / S20 ride alerts (tray / Notification
/// Center and push), next to the in-app lime banner.
///
/// Implemented by `RideNotifications` (lib/notifications).
abstract interface class RideAlertNotifier {
  /// Posts [alert] as a system notification. Never throws.
  Future<void> show(RideAlert alert);

  /// Fires when a push arrives while the app is open, so the alerts feed is
  /// re-read right away instead of at the next poll.
  Stream<void> get pushReceived;
}
