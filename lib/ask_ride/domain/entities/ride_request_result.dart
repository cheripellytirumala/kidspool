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
    this.dropoff,
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

  /// Custom drop-off (`dropoffAddress`); `null` → the kids' school.
  final DropOffAddress? dropoff;

  @override
  List<Object?> get props => [
    kidIds,
    pickupDate,
    pickupTime,
    timeZone,
    pickupAddressId,
    note,
    dropoff,
  ];
}

/// A drop-off anywhere (picked from Google search), sent to
/// `create_ride_request` as `dropoffAddress` — same shape as
/// `pickupAddress`.
class DropOffAddress extends Equatable {
  const DropOffAddress({
    required this.label,
    required this.latitude,
    required this.longitude,
    this.addressLine1 = '',
    this.city = '',
    this.state = '',
    this.zip = '',
  });

  /// e.g. `Bluewave Swim Club`.
  final String label;
  final String addressLine1;
  final String city;
  final String state;
  final String zip;
  final double latitude;
  final double longitude;

  @override
  List<Object?> get props => [
    label,
    addressLine1,
    city,
    state,
    zip,
    latitude,
    longitude,
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
