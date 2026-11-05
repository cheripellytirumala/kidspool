import 'package:equatable/equatable.dart';

/// What a notification is about (`get_my_notifications().kind`).
enum NotificationKind {
  // The user's own ride requests
  rideConfirmed('ride_confirmed'),
  rideStarted('ride_started'),
  pickedUp('picked_up'),
  rideArrived('ride_arrived'),
  driverCancelled('driver_cancelled'),
  rideMissed('ride_missed'),
  rideExpired('ride_expired'),

  // As a Ride Partner
  rideRequest('ride_request'),
  offerDeclined('offer_declined'),

  /// A kind this app version doesn't know yet: shown, not tappable.
  other('other');

  const NotificationKind(this.value);

  final String value;

  static NotificationKind fromValue(String? value) => values.firstWhere(
    (k) => k.value == value,
    orElse: () => NotificationKind.other,
  );
}

/// One row of F25b · Notifications.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.body,
    this.requestId,
    this.iAmDriver = false,
    this.otherName,
    this.otherInitials,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String? body;
  final DateTime createdAt;

  /// `ride_requests.id` the notification is about.
  final String? requestId;

  /// The user got this as the Ride Partner (else as the asking parent).
  final bool iAmDriver;

  /// The other parent (driver or asking parent), when there is one.
  final String? otherName;
  final String? otherInitials;

  @override
  List<Object?> get props => [
    id,
    kind,
    title,
    body,
    createdAt,
    requestId,
    iAmDriver,
    otherName,
    otherInitials,
  ];
}
