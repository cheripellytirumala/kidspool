import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/data_sources/local/place_catalog.dart';
import '../../domain/entities/place.dart';
import '../../domain/repositories/kids_repository.dart';

/// State of the F09 "Add school & activity" sheet: tab and search query.
/// Schools are searched on the server (`get_schools`, debounced);
/// activities come from the local [PlaceCatalog].
class PlaceSearchProvider extends ChangeNotifier {
  PlaceSearchProvider(this._catalog, this._repository);

  final PlaceCatalog _catalog;
  final KidsRepository _repository;

  PlaceKind _kind = PlaceKind.school;
  String _query = '';
  List<Place> _schools = const [];
  bool _searching = false;
  String? _errorMessage;
  Timer? _debounce;
  int _requestId = 0;
  bool _disposed = false;

  PlaceKind get kind => _kind;
  String get query => _query;
  bool get isSearching => _searching;
  String? get errorMessage => _errorMessage;

  List<Place> get results => _kind == PlaceKind.school
      ? _schools
      : _catalog.search(PlaceKind.activity, _query);

  void open(PlaceKind kind, {String query = ''}) {
    _kind = kind;
    _query = query;
    _searchSchools(immediate: true);
    _notify();
  }

  void setKind(PlaceKind kind) {
    if (_kind == kind) return;
    _kind = kind;
    _searchSchools(immediate: true);
    _notify();
  }

  void setQuery(String query) {
    _query = query;
    _searchSchools();
    _notify();
  }

  void _searchSchools({bool immediate = false}) {
    if (_kind != PlaceKind.school) return;
    _debounce?.cancel();
    _debounce = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 300),
      _runSchoolSearch,
    );
  }

  Future<void> _runSchoolSearch() async {
    final id = ++_requestId;
    _searching = true;
    _errorMessage = null;
    _notify();
    final result = await _repository.searchSchools(_query);
    if (id != _requestId || _disposed) return; // a newer search is running
    _searching = false;
    result.match(
      (failure) => _errorMessage = failure.message,
      (schools) => _schools = schools,
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
