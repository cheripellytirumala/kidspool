import 'package:equatable/equatable.dart';

/// Who is driving a booked ride and how many parents share its route
/// (`get_request_activity`).
class RideActivity extends Equatable {
  const RideActivity({
    this.driverFirstName,
    this.driverInitials,
    this.driverPhotoUrl,
    this.notifiedCount = 0,
  });

  /// The approved Ride Partner, e.g. "Jen".
  final String? driverFirstName;
  final String? driverInitials;
  final String? driverPhotoUrl;

  /// Parents on this route who were asked for the ride.
  final int notifiedCount;

  @override
  List<Object?> get props => [
    driverFirstName,
    driverInitials,
    driverPhotoUrl,
    notifiedCount,
  ];
}
