import 'package:equatable/equatable.dart';

/// Which lime card a ride notification shows as (S19 / S20).
enum RideAlertKind {
  /// A Ride Partner accepted (the ride is booked) → See ride.
  accepted,

  /// S19 · "Ride started 🚗" → Track live.
  started,

  /// Parent: "Ravi has arrived 📍" with the pick-up PIN → Track live.
  atPickup,

  /// S20 · "Emma reached Lincoln Elementary ✅" → See ride summary.
  arrived;

  /// `get_my_notifications().kind` → ride alert kind; null for notifications
  /// that aren't about a ride in progress (reviews, requests, offers…).
  /// Kinds follow the previous app's `NotificationKind` plus the backend's
  /// ride event types (`started`, `picked_up`, `dropped_off`, `completed`).
  static RideAlertKind? fromValue(String? kind) => switch (kind) {
    'ride_confirmed' ||
    'confirmed' ||
    'offer_accepted' ||
    // Parent: a Ride Partner offered → See ride (accept / decline).
    'offer_received' => accepted,
    // Parent's three ride notifications: started, at pick-up, completed.
    // ("picked_up" is no longer sent; "ride_overdue" is for the driver.)
    'ride_started' || 'started' || 'ride_overdue' => started,
    'driver_at_pickup' => atPickup,
    'school' ||
    'safe_zone' ||
    'checked_in' ||
    'dropped_off' ||
    'arrived' ||
    'ride_arrived' ||
    'completed' ||
    'ride_completed' ||
    'ride_auto_ended' => arrived,
    _ => null,
  };
}

/// One ride notification from `get_my_notifications`.
class RideAlert extends Equatable {
  const RideAlert({
    required this.id,
    required this.kind,
    required this.title,
    this.body,
    this.requestId,
    required this.createdAt,
  });

  final String id;
  final RideAlertKind kind;
  final String title;
  final String? body;

  /// The ride to open, from the notification's `data`.
  final String? requestId;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, kind, title, body, requestId, createdAt];
}
