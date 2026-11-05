import 'package:equatable/equatable.dart';

/// Status of a ride request (`ride_status`).
enum RideStatus {
  open,
  confirmed,
  inProgress,
  completed,
  cancelled,
  expired,
  missed;

  static RideStatus parse(String? value) => switch (value) {
    'confirmed' => confirmed,
    'in_progress' => inProgress,
    'completed' => completed,
    'cancelled' => cancelled,
    'expired' => expired,
    'missed' => missed,
    _ => open,
  };

  String get label => switch (this) {
    open => 'Asking parents',
    confirmed => 'Driver confirmed',
    inProgress => 'On the way',
    completed => 'Done',
    cancelled => 'Cancelled',
    expired => 'No driver found',
    missed => 'Missed',
  };
}

/// A ride the parent asked for (`get_my_ride_requests`), or one they drive
/// for another family (`get_my_drives`, [isDrive]).
class UpcomingRide extends Equatable {
  const UpcomingRide({
    required this.id,
    required this.status,
    required this.kidNames,
    required this.schoolName,
    required this.pickupAt,
    required this.pickupLabel,
    this.dropoffLabel,
    this.isDrive = false,
  });

  final String id;
  final RideStatus status;
  final List<String> kidNames;
  final String schoolName;

  /// Pick-up time (device local time).
  final DateTime pickupAt;

  /// e.g. "Home".
  final String pickupLabel;

  /// Custom drop-off (`dropoff.label`); `null` → the ride goes to school.
  final String? dropoffLabel;

  /// Where the kids are dropped off: [dropoffLabel], else [schoolName].
  String get destinationName => dropoffLabel ?? schoolName;

  /// True when the user is the Ride Partner driving another family's kids.
  final bool isDrive;

  /// Confirmed or under way: a ride partner is booked.
  bool get isBooked =>
      status == RideStatus.confirmed || status == RideStatus.inProgress;

  /// "Emma", "Emma & Noah", "Emma +2".
  String get kidsLabel => kidNames.isEmpty
      ? 'your kid'
      : kidNames.length <= 2
      ? kidNames.join(' & ')
      : '${kidNames.first} +${kidNames.length - 1}';

  /// "Emma & Noah · Home → Lincoln Elementary" (or the custom drop-off).
  String get title {
    return '$kidsLabel · $pickupLabel → $destinationName';
  }

  @override
  List<Object?> get props => [
    id,
    status,
    kidNames,
    schoolName,
    pickupAt,
    pickupLabel,
    dropoffLabel,
    isDrive,
  ];
}
