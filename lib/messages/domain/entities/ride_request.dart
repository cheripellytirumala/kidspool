import 'package:equatable/equatable.dart';

import 'chat_person.dart';

/// `ride_requests.status`.
enum RideRequestStatus {
  open,
  confirmed,
  inProgress,
  completed,
  cancelled,
  expired,
  missed;

  static RideRequestStatus parse(String? value) => switch (value) {
    'confirmed' => confirmed,
    'in_progress' => inProgress,
    'completed' => completed,
    'cancelled' => cancelled,
    'expired' => expired,
    'missed' => missed,
    _ => open,
  };

  /// Booked: a Ride Partner is on it (or it already happened).
  bool get isBooked =>
      this == confirmed || this == inProgress || this == completed;

  bool get isOver =>
      this == completed ||
      this == cancelled ||
      this == expired ||
      this == missed;
}

/// An offer from a Ride Partner on the user's own request
/// (`get_ride_request.offers[]`).
class RideOffer extends Equatable {
  const RideOffer({
    required this.offerId,
    required this.partner,
    this.createdAt,
    this.daysInOffer = 1,
  });

  final String offerId;
  final ChatPerson partner;
  final DateTime? createdAt;

  /// Days of a repeating ride this offer covers.
  final int daysInOffer;

  @override
  List<Object?> get props => [offerId, partner, createdAt, daysInOffer];
}

/// A ride request in the Messages tab.
///
/// [isMine] — the user asked for it (`ride_request_json`), with [offers] from
/// Ride Partners. Otherwise it was sent to the user as a Ride Partner
/// (`driver_request_json`), with [parent] and the user's [myOfferId].
class RideRequest extends Equatable {
  const RideRequest({
    required this.id,
    required this.isMine,
    required this.status,
    required this.pickupAt,
    required this.pickupLabel,
    required this.destinationName,
    this.seriesId,
    this.estimatedDropoffAt,
    this.kids = const [],
    this.parent,
    this.driver,
    this.offers = const [],
    this.myOfferId,
    this.distanceMiles,
    this.note,
    this.openDaysInSeries = 1,
    this.needsBooster = false,
    this.youAreBusy = false,
  });

  final String id;
  final bool isMine;
  final RideRequestStatus status;
  final DateTime pickupAt;

  /// `Home`, a saved-address label, or the pickup area for Ride Partners.
  final String pickupLabel;

  /// Drop-off label, else the school name.
  final String destinationName;
  final String? seriesId;
  final DateTime? estimatedDropoffAt;
  final List<ChatKid> kids;

  /// The requesting parent (Ride Partner view).
  final ChatPerson? parent;

  /// The confirmed Ride Partner (parent view, once booked).
  final ChatPerson? driver;
  final List<RideOffer> offers;

  /// The user's pending offer on someone else's request.
  final String? myOfferId;

  /// From the Ride Partner's home to the pickup.
  final double? distanceMiles;
  final String? note;
  final int openDaysInSeries;
  final bool needsBooster;
  final bool youAreBusy;

  bool get isOpen => status == RideRequestStatus.open;
  bool get offered => myOfferId != null;
  bool get repeats => openDaysInSeries > 1;
  List<String> get kidNames => [for (final k in kids) k.firstName];

  /// Offer from Ride Partner [driverId] on this (own) request.
  RideOffer? offerFrom(String? driverId) {
    if (driverId == null) return null;
    for (final o in offers) {
      if (o.partner.id == driverId) return o;
    }
    return null;
  }

  RideRequest copyWith({
    RideRequestStatus? status,
    String? myOfferId,
    bool clearMyOffer = false,
    List<ChatKid>? kids,
    List<RideOffer>? offers,
    ChatPerson? driver,
  }) {
    return RideRequest(
      id: id,
      isMine: isMine,
      status: status ?? this.status,
      pickupAt: pickupAt,
      pickupLabel: pickupLabel,
      destinationName: destinationName,
      seriesId: seriesId,
      estimatedDropoffAt: estimatedDropoffAt,
      kids: kids ?? this.kids,
      parent: parent,
      driver: driver ?? this.driver,
      offers: offers ?? this.offers,
      myOfferId: clearMyOffer ? null : (myOfferId ?? this.myOfferId),
      distanceMiles: distanceMiles,
      note: note,
      openDaysInSeries: openDaysInSeries,
      needsBooster: needsBooster,
      youAreBusy: youAreBusy,
    );
  }

  @override
  List<Object?> get props => [
    id,
    isMine,
    status,
    pickupAt,
    pickupLabel,
    destinationName,
    seriesId,
    estimatedDropoffAt,
    kids,
    parent,
    driver,
    offers,
    myOfferId,
    distanceMiles,
    note,
    openDaysInSeries,
    needsBooster,
    youAreBusy,
  ];
}

/// Requests tab (F24a): the user's own open requests (with offers) and the
/// open requests sent to the user as a Ride Partner.
class RequestsInbox extends Equatable {
  const RequestsInbox({this.mine = const [], this.incoming = const []});

  final List<RideRequest> mine;
  final List<RideRequest> incoming;

  /// Offers waiting for the user + requests the user hasn't answered.
  int get needsAnswerCount =>
      mine.fold<int>(0, (n, r) => n + r.offers.length) +
      incoming.where((r) => !r.offered).length;

  bool get isEmpty => mine.isEmpty && incoming.isEmpty;

  @override
  List<Object?> get props => [mine, incoming];
}

/// `offer_ride` result.
class OfferOutcome extends Equatable {
  const OfferOutcome({this.offerId, required this.confirmed});

  final String? offerId;

  /// The parent didn't ask to approve: the ride is booked straight away.
  final bool confirmed;

  @override
  List<Object?> get props => [offerId, confirmed];
}

/// `get_request_activity` (parent only).
class RequestActivity extends Equatable {
  const RequestActivity({
    this.notifiedCount = 0,
    this.seenCount = 0,
    this.offersCount = 0,
  });

  /// Families the request was sent to.
  final int notifiedCount;
  final int seenCount;
  final int offersCount;

  @override
  List<Object?> get props => [notifiedCount, seenCount, offersCount];
}
