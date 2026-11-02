import 'package:equatable/equatable.dart';

/// Which lime card a ride notification shows as (S19 / S20).
enum RideAlertKind {
  /// S19 · "Ride started 🚗" → Track live.
  started,

  /// S20 · "Emma reached Lincoln Elementary ✅" → See ride summary.
  arrived;

  /// `get_my_notifications().kind` → ride alert kind; null for notifications
  /// that aren't about a ride in progress (reviews, requests, offers…).
  /// Kinds follow the previous app's `NotificationKind` plus the backend's
  /// ride event types (`started`, `picked_up`, `dropped_off`, `completed`).
  static RideAlertKind? fromValue(String? kind) => switch (kind) {
    'ride_started' || 'started' || 'picked_up' => started,
    'school' ||
    'safe_zone' ||
    'checked_in' ||
    'dropped_off' ||
    'arrived' ||
    'completed' ||
    'ride_completed' => arrived,
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
