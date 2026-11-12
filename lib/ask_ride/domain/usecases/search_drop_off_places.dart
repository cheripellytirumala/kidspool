import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../../../common/domain/entities/place_search_result.dart';
import '../../../common/domain/repositories/places_repository.dart';
import '../../../common/domain/usecases/search_places_with_fallback.dart';
import '../entities/saved_place.dart';

/// "Drop off at" · Search location: any place, address or zip code from
/// Google Places Text Search (no place type), biased near the pick-up.
class SearchDropOffPlaces
    implements UseCase<List<SavedPlace>, SearchDropOffPlacesParams> {
  const SearchDropOffPlaces(this._places, {this.savedSearch});

  final PlacesRepository _places;

  /// KidPool's own schools / activity places matching the text, searched
  /// before Google (the project's Google quota is small).
  final Future<List<SavedPlace>> Function(String query)? savedSearch;

  /// Radius of the "near home" bias.
  static const double nearRadiusMeters = 5000;

  @override
  Future<Either<Failure, List<SavedPlace>>> call(
    SearchDropOffPlacesParams params,
  ) async {
    final query = buildQuery(params.query);
    if (query.isEmpty) return const Right([]);
    // KidPool's saved places first — no Google call.
    final saved = savedSearch;
    if (saved != null && query.length >= 2) {
      try {
        final found = await saved(query);
        if (found.isNotEmpty) return Right(found);
      } catch (_) {
        // Fall through to Google.
      }
    }
    if (!await _places.isSearchConfigured()) {
      return const Left(
        DeviceFailure('Place search isn’t set up on this build.'),
      );
    }
    // Falls back to Autocomplete + Details when Text Search is over quota.
    final result = await searchPlacesWithFallback(
      _places,
      textQuery: query,
      typed: query,
      nearLatitude: params.nearLatitude,
      nearLongitude: params.nearLongitude,
      radiusMeters: nearRadiusMeters,
    );
    return result.map((places) => [for (final p in places) toPlace(p)]);
  }

  /// What the parent typed, with spaces tidied. A zip code, an address or a
  /// place name all go to Google as typed (no type filter, so a zip code
  /// finds the area and an address finds that address).
  static String buildQuery(String typed) =>
      typed.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// A Google result as a custom drop-off, keeping its coordinates and
  /// address parts for `dropoffAddress`.
  static SavedPlace toPlace(PlaceSearchResult r) {
    final line = r.shortAddress.isNotEmpty
        ? r.shortAddress
        : r.formattedAddress.isNotEmpty
        ? r.formattedAddress
        : r.street;
    final street = r.street.isNotEmpty
        ? r.street
        : r.formattedAddress.split(',').first.trim();
    return SavedPlace(
      id: 'custom:${r.placeId}',
      name: r.name.isNotEmpty ? r.name : street,
      address: [
        line,
        if (r.zip.isNotEmpty && !line.contains(r.zip)) r.zip,
      ].where((p) => p.isNotEmpty).join(' · '),
      kind: PlaceKind.custom,
      latitude: r.latitude,
      longitude: r.longitude,
      addressLine1: street,
      city: r.city,
      state: r.stateCode,
      zip: r.zip,
    );
  }
}

class SearchDropOffPlacesParams extends Equatable {
  const SearchDropOffPlacesParams({
    required this.query,
    this.nearLatitude,
    this.nearLongitude,
  });

  final String query;

  /// Bias point, usually the pick-up address.
  final double? nearLatitude;
  final double? nearLongitude;

  @override
  List<Object?> get props => [query, nearLatitude, nearLongitude];
}
