import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../common/core/usecase/usecase.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/place.dart';
import '../../domain/usecases/get_home_location.dart';
import '../../domain/usecases/search_kid_places.dart';

/// State of the F09 "Add school & activity" sheet: tab and search query.
/// Both tabs search Google Places (debounced), biased near the parent's
/// home.
class PlaceSearchProvider extends ChangeNotifier {
  PlaceSearchProvider({
    required SearchKidPlaces searchPlaces,
    required GetHomeLocation getHomeLocation,
  }) : _search = searchPlaces,
       _getHome = getHomeLocation;

  final SearchKidPlaces _search;
  final GetHomeLocation _getHome;

  PlaceKind _kind = PlaceKind.school;
  String _query = '';
  List<Place> _results = const [];
  bool _searching = false;
  String? _errorMessage;
  Timer? _debounce;
  int _requestId = 0;
  bool _disposed = false;
  Future<GeoPoint?>? _home;

  PlaceKind get kind => _kind;
  String get query => _query;
  bool get isSearching => _searching;
  String? get errorMessage => _errorMessage;
  List<Place> get results => _results;

  void open(PlaceKind kind, {String query = ''}) {
    _kind = kind;
    _query = query;
    _schedule(immediate: true);
    _notify();
  }

  void setKind(PlaceKind kind) {
    if (_kind == kind) return;
    _kind = kind;
    _results = const [];
    _schedule(immediate: true);
    _notify();
  }

  void setQuery(String query) {
    _query = query;
    _schedule();
    _notify();
  }

  void _schedule({bool immediate = false}) {
    _debounce?.cancel();
    _debounce = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 300),
      _run,
    );
  }

  /// Home is looked up once per sheet; failures just mean no bias.
  Future<GeoPoint?> _homeLocation() => _home ??= _getHome(
    const NoParams(),
  ).then((r) => r.toNullable()).catchError((Object _) => null);

  /// Results already fetched in this sheet, by kind + query: switching
  /// tabs or retyping doesn't spend Google quota again.
  final Map<String, List<Place>> _cache = {};

  Future<void> _run() async {
    final cacheKey = '${_kind.name}|${_query.trim().toLowerCase()}';
    if (_cache[cacheKey] case final cached?) {
      ++_requestId;
      _searching = false;
      _errorMessage = null;
      _results = cached;
      _notify();
      return;
    }
    final id = ++_requestId;
    _searching = true;
    _errorMessage = null;
    _notify();
    final near = await _homeLocation();
    if (id != _requestId || _disposed) return;
    final kind = _kind;
    final result = await _search(
      SearchKidPlacesParams(kind: kind, query: _query, near: near),
    );
    if (id != _requestId || _disposed) return; // a newer search is running
    _searching = false;
    result.match(
      (failure) {
        _errorMessage = failure.message;
        _results = const [];
      },
      (places) {
        _results = places;
        _cache[cacheKey] = places;
      },
    );
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
