import 'package:equatable/equatable.dart';

/// Values sent to `create_ride_request` for one pick-up date.
class CreateRideParams extends Equatable {
  const CreateRideParams({
    required this.kidIds,
    required this.pickupDate,
    required this.pickupTime,
    required this.timeZone,
    required this.pickupAddressId,
    required this.note,
  });

  final List<String> kidIds;

  /// Local calendar date of the pick-up.
  final DateTime pickupDate;

  /// "08:30" (24h).
  final String pickupTime;

  /// IANA name, e.g. `America/Los_Angeles`.
  final String timeZone;
  final String pickupAddressId;
  final String note;

  @override
  List<Object?> get props => [
    kidIds,
    pickupDate,
    pickupTime,
    timeZone,
    pickupAddressId,
    note,
  ];
}

/// Result of `create_ride_request`.
class RideRequestResult extends Equatable {
  const RideRequestResult({
    required this.requestIds,
    required this.eligibleDriversCount,
  });

  final List<String> requestIds;

  /// Nearby parents who were notified.
  final int eligibleDriversCount;

  @override
  List<Object?> get props => [requestIds, eligibleDriversCount];
}
