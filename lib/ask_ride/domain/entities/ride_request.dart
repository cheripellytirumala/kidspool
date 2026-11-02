import 'package:equatable/equatable.dart';

import 'ride_schedule.dart';
import 'ride_time.dart';
import 'saved_place.dart';

/// The "Ask for a ride" form (G1) as a plain value. It is kept as a draft
/// while the parent picks families to ask and until the message is sent.
class RideRequest extends Equatable {
  const RideRequest({
    this.kidIds = const [],
    this.pickup,
    this.dropOff,
    this.schedule,
    this.pickupTime,
    this.returnTrip = false,
    this.returnTime,
    this.boosterSeat = false,
    this.note = '',
  });

  final List<String> kidIds;
  final SavedPlace? pickup;
  final SavedPlace? dropOff;
  final RideSchedule? schedule;
  final RideTime? pickupTime;

  /// Ride back from [dropOff] to [pickup] the same day.
  final bool returnTrip;
  final RideTime? returnTime;
  final bool boosterSeat;

  /// Note for the Ride Partner.
  final String note;

  RideRequest copyWith({
    List<String>? kidIds,
    SavedPlace? Function()? pickup,
    SavedPlace? Function()? dropOff,
    RideSchedule? Function()? schedule,
    RideTime? Function()? pickupTime,
    bool? returnTrip,
    RideTime? Function()? returnTime,
    bool? boosterSeat,
    String? note,
  }) {
    return RideRequest(
      kidIds: kidIds ?? this.kidIds,
      pickup: pickup != null ? pickup() : this.pickup,
      dropOff: dropOff != null ? dropOff() : this.dropOff,
      schedule: schedule != null ? schedule() : this.schedule,
      pickupTime: pickupTime != null ? pickupTime() : this.pickupTime,
      returnTrip: returnTrip ?? this.returnTrip,
      returnTime: returnTime != null ? returnTime() : this.returnTime,
      boosterSeat: boosterSeat ?? this.boosterSeat,
      note: note ?? this.note,
    );
  }

  @override
  List<Object?> get props => [
    kidIds,
    pickup,
    dropOff,
    schedule,
    pickupTime,
    returnTrip,
    returnTime,
    boosterSeat,
    note,
  ];
}
