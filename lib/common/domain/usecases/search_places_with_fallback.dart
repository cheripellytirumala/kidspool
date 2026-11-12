import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../entities/place_search_result.dart';
import '../repositories/places_repository.dart';

/// Google Text Search, or — when its daily quota is used up (HTTP 429) —
/// Autocomplete + Place Details, which have their own quotas, so search
/// keeps working.
///
/// [textQuery] goes to Text Search (e.g. "schools in 94110"); [typed] is
/// what the parent typed, used for Autocomplete. With fewer than 2 typed
/// characters the quota failure is returned as is (callers word it).
Future<Either<Failure, List<PlaceSearchResult>>> searchPlacesWithFallback(
  PlacesRepository places, {
  required String textQuery,
  required String typed,
  String? includedType,
  double? nearLatitude,
  double? nearLongitude,
  double radiusMeters = 5000,
  int fallbackResults = 5,
}) async {
  final result = await places.searchText(
    textQuery,
    includedType: includedType,
    nearLatitude: nearLatitude,
    nearLongitude: nearLongitude,
    radiusMeters: radiusMeters,
  );
  final failure = result.getLeft().toNullable();
  if (failure == null || failure.statusCode != 429) return result;

  final input = typed.trim();
  if (input.length < 2) return Left(failure);
  final session = DateTime.now().microsecondsSinceEpoch.toString();
  final suggestions = (await places.search(
    input,
    sessionToken: session,
    nearLatitude: nearLatitude,
    nearLongitude: nearLongitude,
  )).getRight().toNullable();
  if (suggestions == null) return Left(failure);

  final found = <PlaceSearchResult>[];
  for (final s in suggestions.take(fallbackResults)) {
    final d = (await places.details(
      s.placeId,
      sessionToken: session,
    )).toNullable();
    if (d == null) continue;
    found.add(
      PlaceSearchResult(
        placeId: s.placeId,
        name: s.primaryText,
        formattedAddress: d.formatted,
        shortAddress: s.secondaryText,
        street: d.street,
        city: d.city,
        stateCode: d.stateCode,
        zip: d.zip,
        latitude: d.latitude,
        longitude: d.longitude,
      ),
    );
  }
  return Right(found);
}
