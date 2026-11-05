import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/picked_address.dart';
import '../../domain/entities/place_suggestion.dart';
import '../../domain/usecases/get_place_address.dart';
import '../../domain/usecases/resolve_map_position.dart';
import '../../domain/usecases/search_places.dart';

/// State for the Google-map address picker: search-as-you-type suggestions,
/// the address under the pin, and the device location.
class MapAddressPickerProvider extends ChangeNotifier {
  MapAddressPickerProvider({
    required SearchPlaces searchPlaces,
    required GetPlaceAddress getPlaceAddress,
    required ResolveMapPosition resolveMapPosition,
  }) : _searchPlaces = searchPlaces,
       _getPlaceAddress = getPlaceAddress,
       _resolveMapPosition = resolveMapPosition;

  final SearchPlaces _searchPlaces;
  final GetPlaceAddress _getPlaceAddress;
  final ResolveMapPosition _resolveMapPosition;

  static const Duration _debounce = Duration(milliseconds: 350);
  static const int _minQueryLength = 3;

  Timer? _debounceTimer;
  String _sessionToken = _newSessionToken();
  int _searchSeq = 0;
  int _resolveSeq = 0;
  bool _disposed = false;

  String _query = '';
  List<PlaceSuggestion> _suggestions = const [];
  bool _isSearching = false;
  String? _searchError;

  PickedAddress? _address;
  bool _isResolving = false;
  String? _error;

  String get query => _query;
  List<PlaceSuggestion> get suggestions => _suggestions;
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;

  /// Address under the pin (or the chosen suggestion).
  PickedAddress? get address => _address;
  bool get isResolving => _isResolving;
  String? get error => _error;

  bool get canConfirm => !_isResolving && (_address?.isComplete ?? false);

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  void onQueryChanged(String value) {
    _query = value;
    _debounceTimer?.cancel();
    if (value.trim().length < _minQueryLength) {
      _searchSeq++;
      _suggestions = const [];
      _isSearching = false;
      _searchError = null;
      _notify();
      return;
    }
    _isSearching = true;
    _notify();
    _debounceTimer = Timer(_debounce, () => _search(value.trim()));
  }

  Future<void> _search(String query) async {
    final seq = ++_searchSeq;
    final near = _address;
    final result = await _searchPlaces(
      SearchPlacesParams(
        query: query,
        sessionToken: _sessionToken,
        nearLatitude: near?.latitude,
        nearLongitude: near?.longitude,
      ),
    );
    if (seq != _searchSeq) return; // a newer query is running
    _isSearching = false;
    result.match(
      (failure) {
        _suggestions = const [];
        _searchError = failure.message;
      },
      (items) {
        _suggestions = items;
        _searchError = null;
      },
    );
    _notify();
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    _searchSeq++;
    _query = '';
    _suggestions = const [];
    _isSearching = false;
    _searchError = null;
    _notify();
  }

  /// Resolves a suggestion; returns its address so the map can move there.
  Future<PickedAddress?> selectSuggestion(PlaceSuggestion suggestion) async {
    _debounceTimer?.cancel();
    _searchSeq++;
    _suggestions = const [];
    _isSearching = false;
    _query = suggestion.primaryText;

    final picked = await _resolve(
      () => _getPlaceAddress(
        GetPlaceAddressParams(
          placeId: suggestion.placeId,
          sessionToken: _sessionToken,
        ),
      ),
    );
    // A session ends with a details call; start a new one for the next search.
    _sessionToken = _newSessionToken();
    return picked;
  }

  // ---------------------------------------------------------------------------
  // Map position
  // ---------------------------------------------------------------------------

  /// Called when the user stops dragging the map.
  Future<void> onMapSettled(double latitude, double longitude) async {
    final current = _address;
    if (current != null &&
        (current.latitude - latitude).abs() < 1e-6 &&
        (current.longitude - longitude).abs() < 1e-6) {
      return; // camera moved to an address we already have
    }
    await _resolve(
      () => _resolveMapPosition(
        ResolveMapPositionParams(latitude: latitude, longitude: longitude),
      ),
    );
  }

  /// Device location; returns it so the map can move there.
  Future<PickedAddress?> useMyLocation() => _resolve(
    () => _resolveMapPosition(const ResolveMapPositionParams.current()),
  );

  Future<PickedAddress?> _resolve(
    Future<Either<Failure, PickedAddress>> Function() request,
  ) async {
    final seq = ++_resolveSeq;
    _isResolving = true;
    _error = null;
    _notify();

    final result = await request();
    if (seq != _resolveSeq) return null; // superseded by a newer move
    _isResolving = false;
    final picked = result.match((failure) {
      _error = failure.message;
      return null;
    }, (value) => _address = value);
    _notify();
    return picked;
  }

  static String _newSessionToken() {
    final r = Random.secure();
    return List.generate(
      16,
      (_) => r.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    super.dispose();
  }
}
