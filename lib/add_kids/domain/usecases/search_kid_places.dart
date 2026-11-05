import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../../../common/domain/entities/place_search_result.dart';
import '../../../common/domain/repositories/places_repository.dart';
import '../entities/geo_point.dart';
import '../entities/place.dart';
import '../entities/place_search_query.dart';

/// F09 search: schools or activities from Google Places Text Search,
/// biased near the parent's home.
class SearchKidPlaces implements UseCase<List<Place>, SearchKidPlacesParams> {
  const SearchKidPlaces(this._places);

  final PlacesRepository _places;

  /// Radius of the "near home" bias.
  static const double nearRadiusMeters = 5000;

  @override
  Future<Either<Failure, List<Place>>> call(
    SearchKidPlacesParams params,
  ) async {
    if (!await _places.isSearchConfigured()) {
      return Left(
        DeviceFailure(
          params.kind == PlaceKind.school
              ? 'School search isn’t set up on this build.'
              : 'Activity search isn’t set up on this build.',
        ),
      );
    }
    final result = await _places.searchText(
      PlaceSearchQuery.build(params.kind, params.query),
      includedType: PlaceSearchQuery.includedType(params.kind),
      nearLatitude: params.near?.latitude,
      nearLongitude: params.near?.longitude,
      radiusMeters: nearRadiusMeters,
    );
    return result.map(
      (places) => [for (final p in places) toPlace(p, params.kind)],
    );
  }

  /// Maps a Google result to the Kids [Place], keeping the Google id,
  /// coordinates and address parts so a school can be saved later.
  static Place toPlace(PlaceSearchResult r, PlaceKind kind) {
    final line = r.shortAddress.isNotEmpty ? r.shortAddress : r.street;
    final details = [
      line,
      if (r.zip.isNotEmpty && !line.contains(r.zip)) r.zip,
    ].where((p) => p.isNotEmpty).join(' · ');
    return Place(
      id: r.placeId,
      name: r.name,
      category: kind == PlaceKind.school
          ? PlaceCategory.school
          : activityCategory(r.primaryType, r.name),
      details: details.isNotEmpty ? details : r.formattedAddress,
      keywords: [r.city, r.stateCode, r.zip].join(' ').trim(),
      googlePlaceId: r.placeId,
      latitude: r.latitude,
      longitude: r.longitude,
      addressLine: r.street,
      city: r.city,
      state: r.stateCode,
      zip: r.zip,
    );
  }

  /// Google's `primaryType` (or the name) → activity icon.
  static PlaceCategory activityCategory(String? primaryType, String name) {
    final text = '${primaryType ?? ''} ${name.toLowerCase()}';
    if (text.contains('swim') || text.contains('aquatic')) {
      return PlaceCategory.swim;
    }
    if (text.contains('danc') || text.contains('ballet')) {
      return PlaceCategory.dance;
    }
    if (text.contains('music') ||
        text.contains('piano') ||
        text.contains('guitar') ||
        text.contains('concert')) {
      return PlaceCategory.music;
    }
    const sports = [
      'sport',
      'soccer',
      'football',
      'baseball',
      'basketball',
      'athletic',
      'stadium',
      'arena',
      'field',
      'gym',
      'fitness',
      'tennis',
      'golf',
      'skating',
      'martial',
    ];
    if (sports.any(text.contains)) return PlaceCategory.soccer;
    return PlaceCategory.activity;
  }
}

class SearchKidPlacesParams extends Equatable {
  const SearchKidPlacesParams({
    required this.kind,
    required this.query,
    this.near,
  });

  final PlaceKind kind;

  /// What the parent typed (name, zip code or address).
  final String query;

  /// Bias point, usually the default home address.
  final GeoPoint? near;

  @override
  List<Object?> get props => [kind, query, near];
}
