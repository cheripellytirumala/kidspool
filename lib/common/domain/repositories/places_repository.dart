import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../entities/picked_address.dart';
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
}
