import 'package:equatable/equatable.dart';

/// Where a ride ask stands.
enum RideAskStatus {
  /// Waiting for a driver to tap "I can help".
  open,

  /// A driver tapped "I can help": the ride is booked with them.
  taken,
  cancelled;

  static RideAskStatus parse(String? value) => switch (value) {
    'taken' => taken,
    'cancelled' => cancelled,
    _ => open,
  };
}

/// A ride posted as a card in a group chat (`get_group_ride_asks`). The
/// ride request is only created when a driver taps "I can help".
class RideAsk extends Equatable {
  const RideAsk({
    required this.id,
    required this.messageId,
    required this.isMine,
    required this.status,
    this.helperName,
    this.canHelp = false,
    this.days = 1,
    this.requestIds = const [],
    this.isHelper = false,
    this.rideStatus,
  });

  /// The signed-in parent is the driver who said "I can help".
  final bool isHelper;

  /// Status of the booked ride (`in_progress` once the driver started).
  final String? rideStatus;

  /// The driver has started the ride: live tracking is worth opening.
  bool get rideStarted => rideStatus == 'in_progress';

  /// Taken (or withdrawn) and not about the signed-in parent: the card
  /// disappears for them.
  bool get hiddenForMe => status != RideAskStatus.open && !isMine && !isHelper;

  /// The ride request(s) created when a driver said they can help.
  final List<String> requestIds;

  final String id;

  /// The group message the card belongs to.
  final String? messageId;
  final bool isMine;
  final RideAskStatus status;

  /// First name of the driver who said they can help.
  final String? helperName;

  /// The signed-in parent can tap "I can help".
  final bool canHelp;
  final int days;

  @override
  List<Object?> get props => [
    id,
    messageId,
    isMine,
    status,
    helperName,
    canHelp,
    days,
    requestIds,
    isHelper,
    rideStatus,
  ];
}
