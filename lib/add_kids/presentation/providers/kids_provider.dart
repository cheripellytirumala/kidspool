import 'package:flutter/foundation.dart';

import '../../../common/presentation/state/view_state.dart';
import '../../../common/domain/repositories/account_repository.dart';
import '../../data/data_sources/local/place_catalog.dart';
import '../../domain/entities/child.dart';
import '../../domain/entities/place.dart';
import '../../domain/entities/schedule.dart';
import '../../domain/repositories/kids_repository.dart';

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
    PlaceCatalog catalog = const PlaceCatalog(),
  }) : _repository = repository,
       _account = account,
       _catalog = catalog;

  final KidsRepository _repository;
  final AccountRepository _account;
  final PlaceCatalog _catalog;

  ViewStatus _status = ViewStatus.initial;
  String? _errorMessage;
  List<Child> _children = const [];

  /// Activity schedules (local only).
  final List<Schedule> _activities = [];

  /// Schools seen in search results or on kids, for [placeById].
  final Map<String, Place> _schools = {};
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
      notifyListeners();
      return null;
    });
  }

  // ---- Schools --------------------------------------------------------------

  /// Active schools from `get_schools`. Returns the schools, or an error
  /// message.
  Future<(List<Place>, String?)> searchSchools([String query = '']) async {
    final result = await _repository.searchSchools(query);
    return result.match((failure) => (const <Place>[], failure.message), (
      schools,
    ) {
      rememberSchools(schools);
      return (schools, null);
    });
  }

  /// Remembers schools returned by `get_schools` so [placeById] finds them.
  void rememberSchools(Iterable<Place> schools) {
    for (final school in schools) {
      _schools[school.id] = school;
    }
  }

  // ---- Places ---------------------------------------------------------------

  Place? placeById(String id) => _schools[id] ?? _catalog.byId(id);

  /// Places [childId] goes to: the school first, then activities.
  List<Place> placesFor(String childId) {
    final schoolId = childById(childId)?.schoolId;
    return [
      if (schoolId != null) ?placeById(schoolId),
      for (final schedule in _activities)
        if (schedule.childIds.contains(childId))
          ?_catalog.byId(schedule.placeId),
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
      _schools[place.id] = place;
    }
    _pendingPlace = place;
    notifyListeners();
  }

  /// Uses [place] as the pending place when none was picked yet (e.g. F10
  /// opened directly). Does not notify: safe to call while building.
  void ensurePendingPlace(Place place) => _pendingPlace ??= place;

  /// Saves the pending place for [childIds] (F10 "Save"). Schools are saved
  /// on the server (`update-kid` schoolId). Returns an error message or
  /// `null`.
  Future<String?> assignPendingPlace(Set<String> childIds) async {
    final place = _pendingPlace;
    if (place == null) return null;

    if (place.kind == PlaceKind.school) {
      final changed = {
        for (final id in childIds)
          if (childById(id)?.schoolId != place.id) id,
      };
      if (changed.isNotEmpty) {
        _isSaving = true;
        notifyListeners();
        final result = await _repository.assignSchool(
          kidIds: changed,
          schoolId: place.id,
        );
        _isSaving = false;
        final error = result.getLeft().toNullable()?.message;
        if (error != null) {
          notifyListeners();
          return error;
        }
        await load(force: true);
      }
    } else {
      final index = _activities.indexWhere((s) => s.placeId == place.id);
      if (childIds.isEmpty) {
        if (index != -1) _activities.removeAt(index);
      } else if (index == -1) {
        _activities.add(Schedule(placeId: place.id, childIds: {...childIds}));
      } else {
        _activities[index] = _activities[index].copyWith(
          childIds: {...childIds},
        );
      }
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
