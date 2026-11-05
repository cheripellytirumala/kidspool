import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../entities/picked_address.dart';
import '../entities/place_search_result.dart';
import '../entities/place_suggestion.dart';

/// Address search and geocoding for the map picker.
abstract interface class PlacesRepository {
  Future<Either<Failure, List<PlaceSuggestion>>> search(
    String query, {
    required String sessionToken,
    double? nearLatitude,
    double? nearLongitude,
  });

  Future<Either<Failure, PickedAddress>> details(
    String placeId, {
    required String sessionToken,
  });

  /// Address at a map position (when the user drags the pin).
  Future<Either<Failure, PickedAddress>> addressAt(
    double latitude,
    double longitude,
  );

  Future<Either<Failure, PickedAddress>> currentLocation();

  /// Google Text Search ("schools in 94110"), optionally limited to one
  /// place type and biased to [radiusMeters] around a point.
  Future<Either<Failure, List<PlaceSearchResult>>> searchText(
    String query, {
    String? includedType,
    double? nearLatitude,
    double? nearLongitude,
    double radiusMeters = 5000,
  });

  /// Whether Google search has an API key on this build.
  Future<bool> isSearchConfigured();
}
