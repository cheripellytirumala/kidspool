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
  }) : _getRideOptions = getRideOptions,
       _addSavedPlace = addSavedPlace,
       _repository = repository,
       _timeZone = timeZone;

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

  ViewStatus get status => _status;
  bool get isLoading => _status.isLoading;
  String? get errorMessage => _failure?.message;

  List<AskRideKid> get kids => _kids;
  List<SavedPlace> get places => _places;
  RideRequest get draft => _draft;

  /// Number of parents the request was sent to (set by the families screen
  /// via [markSent]).
  int? get sentToCount => _sentToCount;

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

  bool _draftStillValid() =>
      _draft.kidIds.every((id) => _kids.any((k) => k.id == id)) &&
      (_draft.pickup == null || _places.contains(_draft.pickup)) &&
      (_draft.dropOff == null || _places.contains(_draft.dropOff));

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

  bool isKidSelected(String id) => _draft.kidIds.contains(id);

  /// Selecting kids also points the drop-off at their school and turns on
  /// the booster seat when one of them needs it.
  void toggleKid(String id) {
    final ids = [..._draft.kidIds];
    ids.contains(id) ? ids.remove(id) : ids.add(id);
    final selected = [
      for (final kid in _kids)
        if (ids.contains(kid.id)) kid,
    ];
    final schoolIds = {for (final k in selected) k.schoolId};
    final school = schoolIds.length == 1 ? _schoolPlace(schoolIds.first) : null;
    _update(
      _draft.copyWith(
        kidIds: ids,
        dropOff: school == null ? null : () => school,
        boosterSeat: selected.any((k) => k.needsBooster),
      ),
    );
  }

  // ── Route ───────────────────────────────────────────────────────────────

  void setPickup(SavedPlace place) =>
      _update(_draft.copyWith(pickup: () => place));

  void setDropOff(SavedPlace place) =>
      _update(_draft.copyWith(dropOff: () => place));

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

  void swapPlaces() => _update(
    _draft.copyWith(pickup: () => _draft.dropOff, dropOff: () => _draft.pickup),
  );

  // ── Schedule ────────────────────────────────────────────────────────────

  void setOnce({required DateTime date, required RideTime time}) => _update(
    _draft.copyWith(
      schedule: () => OnceSchedule(RideDateFormat.dateOnly(date)),
      pickupTime: () => time,
    ),
  );

  void setCustom({
    required DateTime start,
    required DateTime end,
    required Set<int> weekdays,
    required RideTime time,
  }) => _update(
    _draft.copyWith(
      schedule: () => CustomSchedule(
        start: RideDateFormat.dateOnly(start),
        end: RideDateFormat.dateOnly(end),
        weekdays: Set.unmodifiable(weekdays),
      ),
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
    CustomSchedule(:final start, :final end) =>
      '${RideDateFormat.short(start)} to ${RideDateFormat.short(end)} | '
          '${_draft.pickupTime?.format() ?? ''}',
    _ => 'Choose the days yourself',
  };

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
    if (d.dropOff == null) return 'Choose where to drop off.';
    if (d.pickup == d.dropOff) {
      return 'Pick-up and drop-off can’t be the same place.';
    }
    if (d.pickup!.kind != PlaceKind.home ||
        d.dropOff!.kind != PlaceKind.school) {
      return 'Rides go from one of your addresses to school.';
    }
    final schoolIds = {for (final k in _selectedKids) k.schoolId};
    if (schoolIds.length > 1) return 'Pick kids who go to the same school.';
    if (schoolIds.first != d.dropOff!.id) {
      return 'Drop-off must be ${_selectedKids.first.name}’s school.';
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
      final d = _draft;
      final timeZone = await _timeZone.current();
      final time = d.pickupTime!;
      final hhmm =
          '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';
      final dates = d.schedule!.rideDates;

      var created = 0;
      var notified = 0;
      for (final date in dates) {
        final result = await _repository.createRideRequest(
          CreateRideParams(
            kidIds: d.kidIds,
            pickupDate: date,
            pickupTime: hhmm,
            timeZone: timeZone,
            pickupAddressId: d.pickup!.id,
            note: _noteForDriver(d),
          ),
        );
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

  /// The backend only stores the trip to school; the return trip and an
  /// extra booster request travel in the note for the driver.
  String _noteForDriver(RideRequest d) {
    final kidsNeedBooster = _selectedKids.any((k) => k.needsBooster);
    final parts = [
      d.note.trim(),
      if (d.returnTrip && d.returnTime != null)
        'Return trip home at ${d.returnTime!.format()}, please.',
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
