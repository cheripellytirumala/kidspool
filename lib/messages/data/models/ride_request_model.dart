import '../../../common/core/utils/json_parser.dart';
import '../../core/utils/messages_format.dart';
import '../../domain/entities/chat_person.dart';
import '../../domain/entities/ride_request.dart';

/// JSON → [RideRequest] for the ride RPCs (shapes from the live
/// `ride_request_json`, `driver_request_json` and `driver_card_json`).
abstract final class RideRequestModel {
  /// The user's own request: a `get_my_ride_requests` row, or
  /// `get_ride_request` (which adds `driver` and pending `offers`).
  static RideRequest? mine(Map<String, dynamic> json) {
    final id = json.readString('id');
    final pickupAt = _time(json['pickupAt']);
    if (id == null || pickupAt == null) return null;
    final address = _map(json['pickupAddress']);
    final label =
        _text(address['label']) ?? _text(address['addressLine1']) ?? 'Home';
    final driverJson = json['driver'];
    return RideRequest(
      id: id,
      isMine: true,
      status: RideRequestStatus.parse(json.readString('status')),
      pickupAt: pickupAt,
      pickupLabel: label,
      destinationName: _destination(json),
      seriesId: json.readString('seriesId'),
      estimatedDropoffAt: _time(json['estimatedDropoffAt']),
      kids: _kids(json),
      driver: driverJson is Map ? person(_map(driverJson)) : null,
      offers: [
        for (final o in (json['offers'] is List ? json['offers'] as List : []))
          if (o is Map) ?offer(Map<String, dynamic>.from(o)),
      ],
      note: _text(json['note']),
      needsBooster: json.readBool('needsBooster') ?? false,
    );
  }

  /// A request sent to the user as a Ride Partner: a `get_open_requests` or
  /// `get_my_drives` row (`driver_request_json` + `myOffer`, …).
  static RideRequest? incoming(Map<String, dynamic> json) {
    final id = json.readString('id');
    final pickupAt = _time(json['pickupAt']);
    if (id == null || pickupAt == null) return null;
    final address = _map(json['pickupAddress']);
    final parent = _map(json['parent']);
    final first = _text(parent['firstName']) ?? 'A parent';
    final last = _text(parent['lastName']);
    final myOffer = _map(json['myOffer']);
    final offerStatus = _text(myOffer['status']);
    return RideRequest(
      id: id,
      isMine: false,
      status: RideRequestStatus.parse(json.readString('status')),
      pickupAt: pickupAt,
      // The exact address only comes once the user drives this ride.
      pickupLabel:
          _text(address['label']) ??
          _text(address['addressLine1']) ??
          _text(address['city']) ??
          'Home',
      destinationName: _destination(json),
      seriesId: json.readString('seriesId'),
      estimatedDropoffAt: _time(json['estimatedDropoffAt']),
      kids: _kids(json),
      parent: ChatPerson(
        firstName: first,
        lastName: last,
        initials:
            _text(parent['initials']) ?? MessagesFormat.initials(first, last),
        phone: _text(parent['phone']),
      ),
      myOfferId: offerStatus == null || offerStatus == 'pending'
          ? _text(myOffer['offerId'])
          : null,
      distanceMiles: json.readDouble('distanceFromYouMiles'),
      note: _text(json['note']),
      openDaysInSeries: json.readInt('openDaysInSeries') ?? 1,
      needsBooster: json.readBool('needsBooster') ?? false,
      youAreBusy: json.readBool('youAreBusy') ?? false,
    );
  }

  /// `get_ride_request.offers[]`; rows without an id or driver are skipped.
  static RideOffer? offer(Map<String, dynamic> json) {
    final offerId = json.readString('offerId');
    final driver = json['driver'];
    if (offerId == null || driver is! Map) return null;
    final status = _text(json['status']);
    if (status != null && status != 'pending') return null;
    return RideOffer(
      offerId: offerId,
      partner: person(_map(driver)),
      createdAt: _time(json['createdAt']),
      daysInOffer: json.readInt('daysInOffer') ?? 1,
    );
  }

  /// `driver_card_json` (also `get_my_ride_chats.other`).
  static ChatPerson person(Map<String, dynamic> json) {
    final first = _text(json['firstName']) ?? 'Ride Partner';
    final last = _text(json['lastName']);
    return ChatPerson(
      id: _text(json['id']),
      firstName: first,
      lastName: last,
      initials: _text(json['initials']) ?? MessagesFormat.initials(first, last),
      phone: _text(json['phone']),
      photoUrl: _text(json['photoUrl']) ?? _text(json['avatarUrl']),
      distanceMiles: json.readDouble('distanceMiles'),
      ridesGiven: json.readInt('ridesGiven') ?? 0,
      kidsAtSchool: [
        for (final k
            in (json['kidsAtSchool'] is List
                ? json['kidsAtSchool'] as List
                : const []))
          if (k is String && k.trim().isNotEmpty) k.trim(),
      ],
    );
  }

  /// `get_request_activity`.
  static RequestActivity activity(Map<String, dynamic> json) => RequestActivity(
    notifiedCount: json.readInt('notifiedCount') ?? 0,
    seenCount: json.readInt('seenCount') ?? 0,
    offersCount: json.readInt('offersCount') ?? 0,
  );

  /// `offer_ride` → `{groupId, status, offers: [{offerId, requestId}]}`.
  static OfferOutcome offerOutcome(Object? json, String requestId) {
    final map = _map(json);
    String? offerId;
    final offers = map['offers'];
    if (offers is List) {
      for (final o in offers.whereType<Map>()) {
        if (o['requestId']?.toString() == requestId) {
          offerId = o['offerId']?.toString();
        }
      }
      offerId ??= offers.whereType<Map>().firstOrNull?['offerId']?.toString();
    }
    return OfferOutcome(
      offerId: offerId,
      confirmed: map['status'] == 'confirmed',
    );
  }

  // ----------------------------------------------------------- helpers

  /// Drop-off label (custom drop-off), else the school name.
  static String _destination(Map<String, dynamic> json) {
    final dropoff = _map(json['dropoff']);
    final school = _map(json['school']);
    return _text(dropoff['label']) ??
        _text(dropoff['addressLine1']) ??
        _text(school['name']) ??
        'School';
  }

  static List<ChatKid> _kids(Map<String, dynamic> json) => [
    for (final k in (json['kids'] is List ? json['kids'] as List : const []))
      if (k is Map && _text(k['firstName']) != null)
        ChatKid(
          firstName: _text(k['firstName'])!,
          photoPath: _text(k['photoPath']),
        ),
  ];

  static Map<String, dynamic> _map(Object? value) => value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};

  static String? _text(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _time(Object? value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
}
