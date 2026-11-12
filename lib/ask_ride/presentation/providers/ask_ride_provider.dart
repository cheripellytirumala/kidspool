import 'package:flutter/foundation.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../../common/core/usecase/usecase.dart';
import '../../core/utils/ride_date_format.dart';
import '../../domain/entities/ask_ride_kid.dart';
import '../../domain/entities/ride_request.dart';
import '../../domain/entities/ride_schedule.dart';
import '../../domain/entities/ride_time.dart';
import '../../domain/entities/saved_place.dart';
import '../../domain/repositories/ask_ride_repository.dart';
import '../../domain/entities/ride_request_result.dart';
import '../../domain/usecases/add_saved_place.dart';
import '../../domain/usecases/get_ride_options.dart';
import '../../../common/domain/entities/picked_address.dart';
import '../../core/constants/ask_ride_api_constants.dart';
import '../../../common/core/services/time_zone_service.dart';

/// State holder for the AskRide flow (G1 → families → F20).
///
/// Kids, saved addresses and schools come from the server. "Next" creates
/// the ride request(s) with `create_ride_request` — one call per chosen
/// day — which also notifies eligible nearby parents.
///
/// Registered as a lazy singleton so the [draft] survives navigating to the
/// families screen and the "Message sent" screen. Call [reset] once the flow
/// is finished.
class AskRideProvider extends ChangeNotifier {
  AskRideProvider({
    required GetRideOptions getRideOptions,
    required AddSavedPlace addSavedPlace,
    required AskRideRepository repository,
    required TimeZoneService timeZone,
    Future<RideGroupTarget?> Function(String schoolName)? findGroup,
    List<({SavedPlace place, Set<String> kidIds})> Function()? activities,
    Future<String?> Function(String groupId, String text)? postToGroup,
    Future<(bool deployed, String? error)> Function(
      String groupId,
      List<CreateRideParams> rides,
      String summary,
    )?
    postAsk,
  }) : _getRideOptions = getRideOptions,
       _postAsk = postAsk,
       _addSavedPlace = addSavedPlace,
       _repository = repository,
       _timeZone = timeZone,
       _findGroup = findGroup,
       _activities = activities,
       _postToGroup = postToGroup;

  /// The kids' activities (kept on the device), as drop-off places.
  final List<({SavedPlace place, Set<String> kidIds})> Function()? _activities;

  /// Activities of the selected kids (any kid when none is selected), for
  /// the "Drop off at" sheet.
  List<SavedPlace> get activityPlaces {
    final all = _activities?.call() ?? const [];
    final selected = _draft.kidIds.toSet();
    return [
      for (final a in all)
        if (a.place.hasCoordinates &&
            (selected.isEmpty || a.kidIds.any(selected.contains)))
          a.place,
    ];
  }

  /// The user's ride group for a school, if they already have one.
  final Future<RideGroupTarget?> Function(String schoolName)? _findGroup;

  /// Posts a ride card in a group (`post_ride_ask`); `deployed` is false
  /// while that SQL isn't on the server.
  final Future<(bool deployed, String? error)> Function(
    String groupId,
    List<CreateRideParams> rides,
    String summary,
  )?
  _postAsk;

  /// Posts a message in a ride group; returns an error or null.
  final Future<String?> Function(String groupId, String text)? _postToGroup;

  final GetRideOptions _getRideOptions;
  final AddSavedPlace _addSavedPlace;
  final AskRideRepository _repository;
  final TimeZoneService _timeZone;

  /// Safety cap for "Custom" schedules (one request per day).
  static const int maxRideDays = 20;
  bool _isSending = false;
  bool get isSending => _isSending;

  bool _isSavingAddress = false;
  bool get isSavingAddress => _isSavingAddress;

  ViewStatus _status = ViewStatus.initial;
  Failure? _failure;

  List<AskRideKid> _kids = const [];
  List<SavedPlace> _places = const [];
  RideRequest _draft = const RideRequest();
  bool _submitted = false;
  int? _sentToCount;
  List<String> _createdRequestIds = const [];

  ViewStatus get status => _status;
  bool get isLoading => _status.isLoading;
  String? get errorMessage => _failure?.message;

  List<AskRideKid> get kids => _kids;
  List<SavedPlace> get places => _places;
  RideRequest get draft => _draft;

  /// Number of parents the request was sent to (set by the families screen
  /// via [markSent]).
  int? get sentToCount => _sentToCount;

  /// Requests made by the last [submit], first ride first. The families
  /// screen sends the parent's message in the first one's chat.
  List<String> get createdRequestIds => _createdRequestIds;

  /// Defaults: first kid, default address → their school, 8:00 AM pick-up.
  static const RideTime defaultPickupTime = RideTime(8, 0);
  static const RideTime defaultReturnTime = RideTime(15, 30);

  /// Loads kids and places. Reloads on every open so new kids/addresses
  /// show up; the draft is kept unless [reset] was called.
  Future<void> load() async {
    if (_status.isLoading) return;
    final hadData = _status.isSuccess;
    _setStatus(ViewStatus.loading);
    final result = await _getRideOptions(const NoParams());
    result.match(
      (failure) => _setStatus(ViewStatus.failure, failure: failure),
      (options) {
        _kids = options.kids;
        _places = options.places;
        if (!hadData || !_draftStillValid()) _draft = _initialDraft();
        _setStatus(ViewStatus.success);
      },
    );
  }

  RideRequest _initialDraft() {
    final kid = _kids.firstOrNull;
    final home =
        _places
            .where((p) => p.kind == PlaceKind.home && p.detail == 'default')
            .firstOrNull ??
        _places.where((p) => p.kind == PlaceKind.home).firstOrNull;
    return RideRequest(
      kidIds: [?kid?.id],
      pickup: home,
      dropOff: _schoolPlace(kid?.schoolId),
      pickupTime: defaultPickupTime,
      returnTrip: false,
      returnTime: defaultReturnTime,
      boosterSeat: kid?.needsBooster ?? false,
    );
  }

  bool _draftStillValid() {
    final home = isRideHome ? _draft.dropOff : _draft.pickup;
    final away = isRideHome ? _draft.pickup : _draft.dropOff;
    return _draft.kidIds.every((id) => _kids.any((k) => k.id == id)) &&
        (home == null ||
            (_places.contains(home) && home.kind == PlaceKind.home)) &&
        (away == null ||
            away.isCustom ||
            (_places.contains(away) && away.kind == PlaceKind.school));
  }

  /// The ride goes from the school (or a picked place) back home — after
  /// "Swap". Otherwise it goes from home to the school or a picked place.
  bool get isRideHome {
    final pickup = _draft.pickup;
    final dropOff = _draft.dropOff;
    if (pickup != null) return pickup.kind != PlaceKind.home;
    return dropOff != null && dropOff.kind == PlaceKind.home;
  }

  /// Reverses the route: home → school becomes school → home and back.
  void swapRoute() => _update(
    _draft.copyWith(pickup: () => _draft.dropOff, dropOff: () => _draft.pickup),
  );

  SavedPlace? _schoolPlace(String? schoolId) => schoolId == null
      ? null
      : _places
            .where((p) => p.kind == PlaceKind.school && p.id == schoolId)
            .firstOrNull;

  List<AskRideKid> get _selectedKids => [
    for (final kid in _kids)
      if (_draft.kidIds.contains(kid.id)) kid,
  ];

  // ── Kids ────────────────────────────────────────────────────────────────

  /// Selected kids with no school yet (added later from Profile): the ride
  /// can't go to "their school" until one is set.
  List<AskRideKid> get selectedKidsWithoutSchool => [
    for (final k in _selectedKids)
      if (k.schoolId == null) k,
  ];

  /// The school to offer them: a selected sibling's, else any kid's.
  SavedPlace? get siblingSchool {
    for (final k in [..._selectedKids, ..._kids]) {
      final school = _schoolPlace(k.schoolId);
      if (school != null) return school;
    }
    return null;
  }

  bool _isSettingSchool = false;
  bool get isSettingSchool => _isSettingSchool;

  /// "Same school": gives [kid] [school], reloads the kids and points the
  /// ride at that school. Returns an error message, or null.
  Future<String?> giveKidSchool(AskRideKid kid, SavedPlace school) async {
    if (_isSettingSchool) return null;
    _isSettingSchool = true;
    notifyListeners();
    final result = await _repository.setKidSchool(kid.id, school.id);
    final failure = result.getLeft().toNullable();
    if (failure == null) {
      await load();
      final ids = {for (final k in _selectedKids) k.schoolId};
      final target = ids.length == 1 ? _schoolPlace(ids.first) : null;
      if (target != null) {
        _draft = isRideHome
            ? _draft.copyWith(pickup: () => target)
            : _draft.copyWith(dropOff: () => target);
      }
    }
    _isSettingSchool = false;
    notifyListeners();
    return failure?.message;
  }

  bool isKidSelected(String id) => _draft.kidIds.contains(id);

  /// Selecting kids also points the drop-off at their school (unless a
  /// custom drop-off was picked) and turns on the booster seat when one of
  /// them needs it.
  void toggleKid(String id) {
    final ids = [..._draft.kidIds];
    ids.contains(id) ? ids.remove(id) : ids.add(id);
    final selected = [
      for (final kid in _kids)
        if (ids.contains(kid.id)) kid,
    ];
    final schoolIds = {for (final k in selected) k.schoolId};
    final school = schoolIds.length == 1 ? _schoolPlace(schoolIds.first) : null;
    final rideHome = isRideHome;
    final away = rideHome ? _draft.pickup : _draft.dropOff;
    final keepCustom = away?.isCustom ?? false;
    final setSchool = school == null || keepCustom ? null : () => school;
    _update(
      _draft.copyWith(
        kidIds: ids,
        pickup: rideHome ? setSchool : null,
        dropOff: rideHome ? null : setSchool,
        boosterSeat: selected.any((k) => k.needsBooster),
      ),
    );
  }

  // ── Route ───────────────────────────────────────────────────────────────

  void setPickup(SavedPlace place) =>
      _update(_draft.copyWith(pickup: () => place));

  /// Where drop-off searches are biased: the pick-up, else any saved
  /// address with coordinates.
  SavedPlace? get searchNear {
    final pickup = _draft.pickup;
    if (pickup != null && pickup.hasCoordinates) return pickup;
    return _places
        .where((p) => p.kind == PlaceKind.home && p.hasCoordinates)
        .firstOrNull;
  }

  /// A kid's school, or a custom place picked from Google search.
  void setDropOff(SavedPlace place) =>
      _update(_draft.copyWith(dropOff: () => place));

  /// Same saved place, or closer than
  /// [AskRideApiConstants.samePlaceMeters] when both have coordinates.
  static bool isSamePlace(SavedPlace a, SavedPlace b) {
    if (a == b || (a.kind == b.kind && a.id == b.id)) return true;
    final meters = a.metersTo(b);
    return meters != null && meters < AskRideApiConstants.samePlaceMeters;
  }

  /// Saves an address picked on the map and selects it as the pick-up
  /// ([pickup]) or drop-off. Returns an error message, or `null` on success.
  Future<String?> addPickedAddress(
    PickedAddress address, {
    required bool pickup,
  }) async {
    if (_isSavingAddress) return null;
    _isSavingAddress = true;
    notifyListeners();

    final result = await _addSavedPlace(AddSavedPlaceParams(address: address));
    _isSavingAddress = false;
    return result.match(
      (failure) {
        notifyListeners();
        return failure.message;
      },
      (places) {
        _places = places;
        final street = address.street.trim().toLowerCase();
        final added =
            places
                .where((p) => p.address.toLowerCase().startsWith(street))
                .lastOrNull ??
            places.lastOrNull;
        if (added != null) {
          pickup ? setPickup(added) : setDropOff(added);
        } else {
          notifyListeners();
        }
        return null;
      },
    );
  }

  // ── Schedule ────────────────────────────────────────────────────────────

  void setOnce({required DateTime date, required RideTime time}) => _update(
    _draft.copyWith(
      schedule: () => OnceSchedule(RideDateFormat.dateOnly(date)),
      pickupTime: () => time,
    ),
  );

  void setCustom({required Set<DateTime> dates, required RideTime time}) =>
      _update(
        _draft.copyWith(
          schedule: () => CustomSchedule(dates),
          pickupTime: () => time,
        ),
      );

  /// Subtitle of the "Just once" card.
  String get onceSummary => switch (_draft.schedule) {
    OnceSchedule(:final date) =>
      '${RideDateFormat.long(date)} | ${_draft.pickupTime?.format() ?? ''}',
    _ => 'Choose date',
  };

  /// Subtitle of the "Custom" card.
  String get customSummary => switch (_draft.schedule) {
    CustomSchedule(:final dates) when dates.isNotEmpty =>
      '${_daysLabel(dates)} | ${_draft.pickupTime?.format() ?? ''}',
    _ => 'Choose the days yourself',
  };

  /// The ride just asked for, as a chat message ("+ Ride" from a chat):
  /// `🚗 I asked for a ride: Casey · Saved → Lincoln Elementary ·
  /// Wednesday, Nov 12 | 8:00 AM. Can you help?`
  String get chatMessage {
    final d = _draft;
    final when = d.schedule is CustomSchedule ? customSummary : onceSummary;
    final kids = [for (final k in _selectedKids) k.name].join(' & ');
    final parts = [
      if (kids.isNotEmpty) kids,
      '${d.pickup?.name ?? 'Pick-up'} → ${d.dropOff?.name ?? 'Drop-off'}',
      when,
    ];
    return '🚗 I asked for a ride: ${parts.join(' · ')}. Can you help?';
  }

  /// "Nov 11", "Nov 11, Nov 13", "5 days, Nov 11 to Nov 20".
  static String _daysLabel(List<DateTime> dates) {
    if (dates.length <= 2) return dates.map(RideDateFormat.short).join(', ');
    return '${dates.length} days, ${RideDateFormat.short(dates.first)} to '
        '${RideDateFormat.short(dates.last)}';
  }

  // ── Extras ──────────────────────────────────────────────────────────────

  void setReturnTrip(bool value) => _update(
    _draft.copyWith(
      returnTrip: value,
      returnTime: value && _draft.returnTime == null
          ? () => defaultReturnTime
          : null,
    ),
  );

  void setReturnTime(RideTime? time) =>
      _update(_draft.copyWith(returnTime: () => time));

  void setBoosterSeat(bool value) =>
      _update(_draft.copyWith(boosterSeat: value));

  void setNote(String value) =>
      _update(_draft.copyWith(note: value), notify: false);

  // ── Validation & submit ─────────────────────────────────────────────────

  /// First problem with the form, or `null` when it can be sent.
  String? get validationError {
    final d = _draft;
    if (d.kidIds.isEmpty) return 'Choose which kid needs the ride.';
    if (d.pickup == null) return 'Choose where to pick up.';
    if (d.dropOff == null ||
        (d.dropOff!.isCustom && !d.dropOff!.hasCoordinates)) {
      return 'Choose where to drop off.';
    }
    if (isSamePlace(d.pickup!, d.dropOff!)) {
      return AskRideApiConstants.samePlaceMessage;
    }
    final rideHome = isRideHome;
    final home = rideHome ? d.dropOff! : d.pickup!;
    final away = rideHome ? d.pickup! : d.dropOff!;
    if (home.kind != PlaceKind.home || away.kind == PlaceKind.home) {
      return 'Rides go between one of your addresses and school or a place '
          'you pick.';
    }
    if (rideHome && !home.hasCoordinates) {
      return 'This address has no map location. Pick another one.';
    }
    // A custom place doesn't need the kids' school.
    if (away.kind == PlaceKind.school) {
      final schoolIds = {for (final k in _selectedKids) k.schoolId};
      if (schoolIds.length > 1) return 'Pick kids who go to the same school.';
      if (schoolIds.first != away.id) {
        final end = rideHome ? 'Pick-up' : 'Drop-off';
        return '$end must be ${_selectedKids.first.name}’s school.';
      }
    }
    if (d.kidIds.length > 4) return 'A ride can take up to 4 kids.';
    final schedule = d.schedule;
    if (schedule == null) return 'Choose “Just once” or “Custom” days.';
    if (schedule.rideDates.isEmpty) {
      return 'None of the chosen days fall between those dates.';
    }
    if (schedule.rideDates.length > maxRideDays) {
      return 'Choose at most $maxRideDays days at a time.';
    }
    if (d.pickupTime == null) return 'Type a pick-up time.';
    if (d.returnTrip) {
      final back = d.returnTime;
      if (back == null) return 'Type a time for the return trip.';
      if (back.compareTo(d.pickupTime!) <= 0) {
        return 'The return pick-up should be after ${d.pickupTime!.format()}.';
      }
    }
    return null;
  }

  bool get isValid => validationError == null;

  /// Whether the form passed validation; used to show inline hints only
  /// after the first submit attempt.
  bool get submitted => _submitted;

  /// The school this ride goes to (or comes from, on a ride home); null
  /// for a custom place.
  SavedPlace? get rideSchool {
    final away = isRideHome ? _draft.pickup : _draft.dropOff;
    return away?.kind == PlaceKind.school ? away : null;
  }

  /// "Next" when the parent already has a ride group for this school:
  /// creates the ride and posts it in that group. Returns the group to open
  /// (null → no group yet: choose families instead), or an error.
  Future<(RideGroupTarget? group, String? error)> askInExistingGroup() async {
    final school = rideSchool;
    final find = _findGroup;
    final post = _postToGroup;
    if (school == null || find == null || post == null || _isSending) {
      return (null, null);
    }
    _isSending = true;
    notifyListeners();
    RideGroupTarget? group;
    try {
      group = await find(school.name);
    } catch (_) {
      group = null; // can't tell: fall back to choosing families
    }
    _isSending = false;
    notifyListeners();
    if (group == null) return (null, null);
    // A card in the group; the request is created on "I can help".
    final error = await askInGroup(group.id);
    if (error != null) return (null, error);
    return (group, null);
  }

  /// "Next: choose who to ask": checks the form without creating anything
  /// (the request is made when the parent messages families). Returns the
  /// first problem, or null. Also turns on the inline hints.
  String? checkDraft() {
    _submitted = true;
    notifyListeners();
    return validationError;
  }

  /// One `create_ride_request` call per day of the (valid) draft. Ride
  /// home: picks up at the school (or picked place), drops off home.
  Future<(List<CreateRideParams>?, String?)> _rideParams() async {
    final d = _draft;
    final timeZone = await _timeZone.current();
    final time = d.pickupTime!;
    final hhmm =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    final rideHome = isRideHome;
    DropOffAddress? pickupAddress;
    if (rideHome) {
      final from = d.pickup!;
      if (from.kind == PlaceKind.school) {
        final school = await _repository.getSchoolAddress(from);
        final failure = school.getLeft().toNullable();
        if (failure != null) return (null, failure.message);
        pickupAddress = school.getRight().toNullable();
      } else {
        pickupAddress = dropOffAddress(from);
      }
    }
    return (
      [
        for (final date in d.schedule!.rideDates)
          CreateRideParams(
            kidIds: d.kidIds,
            pickupDate: date,
            pickupTime: hhmm,
            timeZone: timeZone,
            pickupAddressId: rideHome ? null : d.pickup!.id,
            pickupAddress: pickupAddress,
            note: _noteForDriver(d),
            dropoff: rideHome
                ? homeAddress(d.dropOff!)
                : dropOffAddress(d.dropOff!),
          ),
      ],
      null,
    );
  }

  /// Posts the ride as a card in [groupId]: nothing is created until a
  /// driver taps "I can help" there. Falls back to creating the request
  /// and posting it as text while the ride-card SQL isn't on the server.
  /// Returns an error message, or null.
  Future<String?> askInGroup(String groupId) async {
    _submitted = true;
    notifyListeners();
    final invalid = validationError;
    if (invalid != null) return invalid;
    final postAsk = _postAsk;
    if (postAsk != null && !_isSending) {
      _isSending = true;
      notifyListeners();
      try {
        final (params, buildError) = await _rideParams();
        if (buildError != null) return buildError;
        // One card per day: each day gets its own "I can help" (and its
        // own request once a driver takes it).
        final dates = _draft.schedule!.rideDates;
        var posted = 0;
        for (final (i, date) in dates.indexed) {
          final (deployed, error) = await postAsk(groupId, [
            params![i],
          ], askSummaryFor(date));
          if (!deployed) {
            if (posted == 0) break; // older server: fall back below
            return null;
          }
          if (error != null) {
            return posted == 0
                ? error
                : 'Posted $posted of ${dates.length} days. '
                      '${RideDateFormat.short(date)}: $error';
          }
          posted++;
        }
        if (posted > 0) return null;
      } finally {
        _isSending = false;
        notifyListeners();
      }
    }
    // Older server: create now and post the ride as a message.
    final error = await submit();
    if (error != null) return error;
    return await _postToGroup?.call(groupId, chatMessage);
  }

  /// One day's ride card: `🚗 Ride needed: Emma · Home → Doon Public
  /// School · Monday, Nov 16 | 8:10 PM. Can anyone help?`
  String askSummaryFor(DateTime date) {
    final d = _draft;
    final kids = [for (final k in _selectedKids) k.name].join(' & ');
    final parts = [
      if (kids.isNotEmpty) kids,
      '${d.pickup?.name ?? 'Pick-up'} → ${d.dropOff?.name ?? 'Drop-off'}',
      '${RideDateFormat.long(date)} | ${d.pickupTime?.format() ?? ''}',
    ];
    return '🚗 Ride needed: ${parts.join(' · ')}. Can anyone help?';
  }

  /// The ride card text: `🚗 Ride needed: Emma · Home → Doon Public School ·
  /// Wednesday, Nov 11 | 8:00 PM. Can anyone help?`
  String get askSummary => chatMessage
      .replaceFirst('🚗 I asked for a ride: ', '🚗 Ride needed: ')
      .replaceFirst('Can you help?', 'Can anyone help?');

  /// Validates the draft and creates the ride request(s). Returns an error
  /// message, or `null` when the parent can move on to choosing families.
  Future<String?> submit() async {
    _submitted = true;
    notifyListeners();
    final invalid = validationError;
    if (invalid != null) return invalid;
    if (_isSending) return null;

    _isSending = true;
    notifyListeners();
    try {
      final (params, buildError) = await _rideParams();
      if (buildError != null) return buildError;
      final dates = _draft.schedule!.rideDates;

      var created = 0;
      var notified = 0;
      final ids = <String>[];
      _createdRequestIds = const [];
      for (final (i, date) in dates.indexed) {
        final result = await _repository.createRideRequest(params![i]);
        final failure = result.getLeft().toNullable();
        if (failure != null) {
          final day = RideDateFormat.short(date);
          if (created == 0) {
            return dates.length == 1
                ? failure.message
                : '$day: ${failure.message}';
          }
          // Some days were created: report where it stopped.
          _sentToCount = notified;
          return 'Asked for $created of ${dates.length} days. '
              '$day: ${failure.message}';
        }
        final ok = result.getRight().toNullable()!;
        created++;
        ids.addAll(ok.requestIds);
        _createdRequestIds = List.unmodifiable(ids);
        if (ok.eligibleDriversCount > notified) {
          notified = ok.eligibleDriversCount;
        }
      }
      _sentToCount = notified;
      return null;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// `dropoffAddress` for a custom drop-off; `null` for a school (the
  /// request then looks exactly like before).
  static DropOffAddress? dropOffAddress(SavedPlace place) {
    if (!place.isCustom || !place.hasCoordinates) return null;
    return DropOffAddress(
      label: place.name,
      addressLine1: place.addressLine1,
      city: place.city,
      state: place.state,
      zip: place.zip,
      latitude: place.latitude!,
      longitude: place.longitude!,
    );
  }

  /// A saved home address as `dropoffAddress` (ride home).
  static DropOffAddress? homeAddress(SavedPlace place) {
    if (!place.hasCoordinates) return null;
    final parts = place.address.split(', ');
    return DropOffAddress(
      label: place.name,
      addressLine1: parts.first,
      city: parts.length > 1 ? parts[1] : '',
      latitude: place.latitude!,
      longitude: place.longitude!,
    );
  }

  /// The backend only stores the one-way trip; the return trip and an
  /// extra booster request travel in the note for the driver.
  String _noteForDriver(RideRequest d) {
    final kidsNeedBooster = _selectedKids.any((k) => k.needsBooster);
    final parts = [
      d.note.trim(),
      if (d.returnTrip && d.returnTime != null)
        'Return trip at ${d.returnTime!.format()}, please.',
      if (d.boosterSeat && !kidsNeedBooster) 'Booster seat needed.',
    ].where((p) => p.isNotEmpty).join(' ');
    return parts.length <= AskRideApiConstants.maxNoteLength
        ? parts
        : parts.substring(0, AskRideApiConstants.maxNoteLength);
  }

  /// Called once the request went out to the selected parents.
  void markSent(int parentCount) {
    _sentToCount = parentCount;
    notifyListeners();
  }

  /// Clears the draft after the flow is finished.
  void reset() {
    _draft = _initialDraft();
    _submitted = false;
    _sentToCount = null;
    notifyListeners();
  }

  void _update(RideRequest draft, {bool notify = true}) {
    if (draft == _draft) return;
    _draft = draft;
    if (notify) notifyListeners();
  }

  void _setStatus(ViewStatus status, {Failure? failure}) {
    _status = status;
    _failure = failure;
    notifyListeners();
  }
}

/// A ride group to open after asking for a ride.
class RideGroupTarget {
  const RideGroupTarget({required this.id, required this.name});

  final String id;
  final String name;
}
