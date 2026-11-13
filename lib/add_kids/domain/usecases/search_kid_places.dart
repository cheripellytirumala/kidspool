import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../../../common/domain/entities/place_search_result.dart';
import '../../../common/domain/repositories/places_repository.dart';
import '../../../common/domain/usecases/search_places_with_fallback.dart';
import '../entities/geo_point.dart';
import '../repositories/kids_repository.dart';
import '../entities/place.dart';
import '../entities/place_search_query.dart';

/// F09 search: schools or activities from Google Places Text Search,
/// biased near the parent's home.
class SearchKidPlaces implements UseCase<List<Place>, SearchKidPlacesParams> {
  const SearchKidPlaces(this._places, {KidsRepository? saved}) : _saved = saved;

  final PlacesRepository _places;

  /// KidPool's own schools / activity places, searched before Google (the
  /// project's Google quota is small).
  final KidsRepository? _saved;

  /// Saved places shown at most, nearest first.
  static const int maxSaved = 20;

  /// With nothing typed, saved places further than this aren't listed.
  static const double savedNearbyMeters = 80000;

  /// Radius of the "near home" bias.
  static const double nearRadiusMeters = 5000;

  @override
  Future<Either<Failure, List<Place>>> call(
    SearchKidPlacesParams params,
  ) async {
    // 1. KidPool's own list first — no Google call.
    final saved = _saved;
    if (!params.online && saved != null) {
      final found = (await saved.searchSavedPlaces(
        params.kind,
        params.query,
      )).getOrElse((_) => const []);
      final near = params.near;
      double? meters(Place p) => near == null
          ? null
          : _distance(near.latitude, near.longitude, p.latitude!, p.longitude!);
      final list = [
        for (final p in found)
          if (params.query.trim().isNotEmpty ||
              (meters(p) ?? 0) <= savedNearbyMeters)
            p,
      ];
      if (near != null) {
        list.sort((a, b) => meters(a)!.compareTo(meters(b)!));
      }
      if (list.isNotEmpty) return Right(list.take(maxSaved).toList());
    }
    // 2. Not found (or "Search Google" tapped): Google.
    if (!await _places.isSearchConfigured()) {
      return Left(
        DeviceFailure(
          params.kind == PlaceKind.school
              ? 'School search isn’t set up on this build.'
              : 'Activity search isn’t set up on this build.',
        ),
      );
    }
    final result = await searchPlacesWithFallback(
      _places,
      textQuery: PlaceSearchQuery.build(params.kind, params.query),
      typed: params.query,
      includedType: PlaceSearchQuery.includedType(params.kind),
      nearLatitude: params.near?.latitude,
      nearLongitude: params.near?.longitude,
      radiusMeters: nearRadiusMeters,
    );
    // Over quota with nothing typed yet: ask for a name.
    if (result.getLeft().toNullable()?.statusCode == 429 &&
        params.query.trim().length < 2) {
      return Left(
        DeviceFailure(
          params.kind == PlaceKind.school
              ? 'Type the school’s name to search.'
              : 'Type the activity’s name to search.',
        ),
      );
    }
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

/// Straight-line metres between two points (haversine).
double _distance(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a.toDouble()));
}

class SearchKidPlacesParams extends Equatable {
  const SearchKidPlacesParams({
    required this.kind,
    required this.query,
    this.near,
    this.online = false,
  });

  /// Skip KidPool's saved places and search Google ("Search Google").
  final bool online;

  final PlaceKind kind;

  /// What the parent typed (name, zip code or address).
  final String query;

  /// Bias point, usually the default home address.
  final GeoPoint? near;

  @override
  List<Object?> get props => [kind, query, near, online];
}
