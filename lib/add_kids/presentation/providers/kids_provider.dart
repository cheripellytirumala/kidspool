import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../common/presentation/state/view_state.dart';
import '../../../common/domain/repositories/account_repository.dart';
import '../../data/data_sources/local/kid_activities_store.dart';
import '../../data/data_sources/local/place_catalog.dart';
import '../../domain/entities/child.dart';
import '../../domain/entities/place.dart';
import '../../domain/entities/schedule.dart';
import '../../domain/repositories/kids_repository.dart';
import '../../domain/usecases/resolve_school_id.dart';

/// Shared state of the Kids onboarding flow (F06 → F12).
///
/// Kids and their school come from the server (`get_my_kids`, saved with
/// `add-kid` / `update-kid` / `delete-kid`). The backend stores one school
/// per kid and has no activities table, so activities (soccer, music…) stay
/// on the device for now.
///
/// Registered as a lazy singleton so every screen of the flow sees the same
/// data. Call [load] when a screen opens.
class KidsProvider extends ChangeNotifier {
  KidsProvider({
    required KidsRepository repository,
    required AccountRepository account,
    required ResolveSchoolId resolveSchoolId,
    PlaceCatalog catalog = const PlaceCatalog(),
    KidActivitiesStore? activitiesStore,
  }) : _activitiesStore = activitiesStore,
       _repository = repository,
       _account = account,
       _resolveSchoolId = resolveSchoolId,
       _catalog = catalog;

  final KidsRepository _repository;
  final AccountRepository _account;
  final ResolveSchoolId _resolveSchoolId;
  final PlaceCatalog _catalog;

  /// Keeps activities on the device across app restarts.
  final KidActivitiesStore? _activitiesStore;
  bool _activitiesRestored = false;

  /// Activities from the device (once, after sign-in); a new phone gets
  /// them from the server.
  void _restoreActivities() {
    final store = _activitiesStore;
    if (store == null || _activitiesRestored) return;
    _activitiesRestored = true;
    final local = store.read();
    _addActivities(local);
    if (local.isEmpty) {
      unawaited(_restoreFromServer());
    } else {
      // Saved on this phone before they synced: send them up once.
      unawaited(_repository.setActivities(local));
    }
  }

  void _addActivities(List<KidActivity> list) {
    for (final a in list) {
      _activityPlaces[a.place.id] = a.place;
      if (!_activities.any((s) => s.placeId == a.place.id)) {
        _activities.add(Schedule(placeId: a.place.id, childIds: a.childIds));
      }
    }
  }

  Future<void> _restoreFromServer() async {
    final result = await _repository.getActivities();
    final list = result.getOrElse((_) => const []);
    if (list.isEmpty) return;
    _addActivities(list);
    await _activitiesStore?.write(list);
    notifyListeners();
  }

  /// Saves activities on the device.
  void _saveActivities() {
    final store = _activitiesStore;
    if (store == null) return;
    final list = <KidActivity>[
      for (final s in _activities)
        if (placeById(s.placeId) case final place?)
          (place: place, childIds: s.childIds),
    ];
    store.write(list);
    // Also on the server, so other families can be matched by activity.
    unawaited(_repository.setActivities(list));
  }

  ViewStatus _status = ViewStatus.initial;
  String? _errorMessage;
  List<Child> _children = const [];

  /// Activity schedules (local only).
  final List<Schedule> _activities = [];

  /// Schools seen in search results or on kids, for [placeById].
  final Map<String, Place> _schools = {};

  /// Activities picked from Google search (local only), by id.
  final Map<String, Place> _activityPlaces = {};

  /// Google place id → `schools.id`, once `school_from_place` answered.
  final Map<String, String> _schoolIdByGoogleId = {};
  String? _activeChildId;
  Place? _pendingPlace;
  bool _isSaving = false;

  /// Parent's first name for the F12 greeting (`get_my_status`).
  String parentFirstName = '';

  ViewStatus get status => _status;
  bool get isLoading => _status.isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  List<Child> get children => List.unmodifiable(_children);
  bool get hasChildren => _children.isNotEmpty;

  /// Loads the kids (and the parent's name once). Safe to call on every
  /// screen open; set [force] to reload after a change.
  Future<void> load({bool force = false}) async {
    _restoreActivities();
    if (_status.isLoading || (_status.isSuccess && !force)) return;
    _status = ViewStatus.loading;
    _errorMessage = null;
    notifyListeners();

    if (parentFirstName.isEmpty) {
      final me = await _account.getMyStatus();
      me.match((_) {}, (status) => parentFirstName = status.firstName);
    }

    final result = await _repository.getKids();
    result.match(
      (failure) {
        _status = ViewStatus.failure;
        _errorMessage = failure.message;
      },
      (kids) {
        _children = kids;
        for (final kid in kids) {
          final id = kid.schoolId;
          if (id != null && !_schools.containsKey(id)) {
            _schools[id] = Place(
              id: id,
              name: kid.schoolName ?? 'School',
              category: PlaceCategory.school,
            );
          }
        }
        _status = ViewStatus.success;
      },
    );
    notifyListeners();
  }

  Child? childById(String? id) {
    for (final child in _children) {
      if (child.id == id) return child;
    }
    return null;
  }

  /// The kid selected in the F08/F11 tabs.
  Child? get activeChild =>
      childById(_activeChildId) ?? (_children.isEmpty ? null : _children.first);

  void selectChild(String id) {
    if (_activeChildId == id) return;
    _activeChildId = id;
    notifyListeners();
  }

  /// Saves [draft] on the server and reloads the list. Returns the kid id,
  /// or `null` on failure (see [errorMessage]).
  Future<String?> saveChild(ChildDraft draft) async {
    if (_isSaving) return null;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    final result = await _repository.saveKid(draft);
    _isSaving = false;
    final id = result.match((failure) {
      _errorMessage = failure.message;
      return null;
    }, (id) => id);
    notifyListeners();
    if (id != null) await load(force: true);
    return id;
  }

  /// Deletes the kid on the server. Returns an error message or `null`.
  Future<String?> removeChild(String id) async {
    final result = await _repository.deleteKid(id);
    return result.match((failure) => failure.message, (_) {
      _children = [
        for (final c in _children)
          if (c.id != id) c,
      ];
      for (final schedule in List.of(_activities)) {
        _removeFromActivity(schedule.placeId, id);
      }
      _saveActivities();
      notifyListeners();
      return null;
    });
  }

  // ---- Schools --------------------------------------------------------------

  // ---- Places ---------------------------------------------------------------

  Place? placeById(String id) =>
      _schools[id] ?? _activityPlaces[id] ?? _catalog.byId(id);

  /// Places [childId] goes to: the school first, then activities.
  List<Place> placesFor(String childId) {
    final schoolId = childById(childId)?.schoolId;
    return [
      if (schoolId != null) ?placeById(schoolId),
      for (final schedule in _activities)
        if (schedule.childIds.contains(childId)) ?placeById(schedule.placeId),
    ];
  }

  int placeCount(String childId) => placesFor(childId).length;

  bool get anyPlaces =>
      _activities.isNotEmpty || _children.any((c) => c.schoolId != null);

  /// "No places yet" / "1 place" / "3 places".
  String placesLabel(String childId) {
    final count = placeCount(childId);
    if (count == 0) return 'No places yet';
    return count == 1 ? '1 place' : '$count places';
  }

  /// "0 places" style used by the F09 chips.
  String placesCountLabel(String childId) {
    final count = placeCount(childId);
    return count == 1 ? '1 place' : '$count places';
  }

  Set<String> childIdsAt(String placeId) {
    if (_schools.containsKey(placeId)) {
      return {
        for (final c in _children)
          if (c.schoolId == placeId) c.id,
      };
    }
    for (final schedule in _activities) {
      if (schedule.placeId == placeId) return schedule.childIds;
    }
    return const {};
  }

  /// Other kids that go to [placeId] besides [childId].
  List<Child> alsoGoing(String placeId, String childId) => [
    for (final id in childIdsAt(placeId))
      if (id != childId) ?childById(id),
  ];

  /// Place picked in the F09 search sheet, waiting for F10 to say who goes.
  Place? get pendingPlace => _pendingPlace;

  void setPendingPlace(Place? place) {
    if (place != null && place.kind == PlaceKind.school) {
      // A Google school saved before already has a schools.id: use it so
      // F10 pre-selects the kids that go there.
      final known = _schoolIdByGoogleId[place.googlePlaceId];
      if (known != null) place = place.copyWith(id: known);
      _schools[place.id] = place;
    } else if (place != null) {
      _activityPlaces[place.id] = place;
    }
    _pendingPlace = place;
    notifyListeners();
  }

  /// Uses [place] as the pending place when none was picked yet (e.g. F10
  /// opened directly). Does not notify: safe to call while building.
  void ensurePendingPlace(Place place) => _pendingPlace ??= place;

  /// Saves the pending place for [childIds] (F10 "Save"). Schools are saved
  /// on the server (`update-kid` schoolId; a Google school first gets its
  /// `schools.id` from `school_from_place`). Returns an error message or
  /// `null`.
  Future<String?> assignPendingPlace(Set<String> childIds) async {
    var place = _pendingPlace;
    if (place == null) return null;

    if (place.kind == PlaceKind.school) {
      if (place.isGooglePlace &&
          childIds.isNotEmpty &&
          !_schoolIdByGoogleId.containsValue(place.id)) {
        _isSaving = true;
        notifyListeners();
        final resolved = await _resolveSchoolId(place);
        final schoolId = resolved.toNullable();
        if (schoolId == null) {
          _isSaving = false;
          notifyListeners();
          return resolved.getLeft().toNullable()?.message;
        }
        _schools.remove(place.id);
        _schoolIdByGoogleId[place.googlePlaceId!] = schoolId;
        place = place.copyWith(id: schoolId);
        _schools[schoolId] = place;
        _pendingPlace = place;
      }
      final schoolId = place.id;
      final changed = {
        for (final id in childIds)
          if (childById(id)?.schoolId != schoolId) id,
      };
      if (changed.isNotEmpty) {
        _isSaving = true;
        notifyListeners();
        final result = await _repository.assignSchool(
          kidIds: changed,
          schoolId: schoolId,
        );
        _isSaving = false;
        final error = result.getLeft().toNullable()?.message;
        if (error != null) {
          notifyListeners();
          return error;
        }
        await load(force: true);
      } else if (_isSaving) {
        _isSaving = false;
      }
    } else {
      final placeId = place.id;
      final index = _activities.indexWhere((s) => s.placeId == placeId);
      if (childIds.isEmpty) {
        if (index != -1) _activities.removeAt(index);
      } else if (index == -1) {
        _activities.add(Schedule(placeId: placeId, childIds: {...childIds}));
      } else {
        _activities[index] = _activities[index].copyWith(
          childIds: {...childIds},
        );
      }
      _saveActivities();
    }
    _pendingPlace = null;
    notifyListeners();
    return null;
  }

  /// Removes [childId] from [placeId] (F11 trash button). Returns an error
  /// message when the place can't be removed (every kid needs a school).
  String? removePlaceFor(String placeId, String childId) {
    if (_schools.containsKey(placeId)) {
      return 'Every child needs a school. Pick another school to change it.';
    }
    _removeFromActivity(placeId, childId);
    _saveActivities();
    notifyListeners();
    return null;
  }

  void _removeFromActivity(String placeId, String childId) {
    final index = _activities.indexWhere((s) => s.placeId == placeId);
    if (index == -1) return;
    final remaining = {..._activities[index].childIds}..remove(childId);
    if (remaining.isEmpty) {
      _activities.removeAt(index);
    } else {
      _activities[index] = _activities[index].copyWith(childIds: remaining);
    }
  }

  // ignore: unused_element
  List<Schedule> get schedules => List.unmodifiable(_activities);
}
