import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/saved_place.dart';
import '../../domain/usecases/search_drop_off_places.dart';

/// "Drop off at" · Search location tab: debounced Google Text Search for
/// any place, address or zip code, biased near [near] (the pick-up).
class DropOffSearchProvider extends ChangeNotifier {
  DropOffSearchProvider({required SearchDropOffPlaces searchPlaces})
    : _search = searchPlaces;

  final SearchDropOffPlaces _search;

  static const Duration debounce = Duration(milliseconds: 350);

  String _query = '';
  List<SavedPlace> _results = const [];
  bool _searching = false;
  String? _errorMessage;
  Timer? _debounce;
  int _requestId = 0;
  bool _disposed = false;
  double? _nearLatitude;
  double? _nearLongitude;

  String get query => _query;
  List<SavedPlace> get results => _results;
  bool get isSearching => _searching;
  String? get errorMessage => _errorMessage;

  /// Nothing typed yet: the sheet shows a hint instead of results.
  bool get isIdle => SearchDropOffPlaces.buildQuery(_query).isEmpty;

  /// Where results are biased (usually the pick-up address).
  void setNear(SavedPlace? place) {
    _nearLatitude = place?.latitude;
    _nearLongitude = place?.longitude;
  }

  void setQuery(String query) {
    _query = query;
    _debounce?.cancel();
    if (isIdle) {
      _requestId++; // drop any search still running
      _results = const [];
      _searching = false;
      _errorMessage = null;
    } else {
      _debounce = Timer(debounce, _run);
    }
    _notify();
  }

  Future<void> _run() async {
    final id = ++_requestId;
    _searching = true;
    _errorMessage = null;
    _notify();
    final result = await _search(
      SearchDropOffPlacesParams(
        query: _query,
        nearLatitude: _nearLatitude,
        nearLongitude: _nearLongitude,
      ),
    );
    if (id != _requestId || _disposed) return; // a newer search is running
    _searching = false;
    result.match((failure) {
      _errorMessage = failure.message;
      _results = const [];
    }, (places) => _results = places);
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
