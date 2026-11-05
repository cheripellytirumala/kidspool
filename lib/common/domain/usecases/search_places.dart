import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../../core/usecase/usecase.dart';
import '../entities/place_suggestion.dart';
import '../repositories/places_repository.dart';

class SearchPlaces
    implements UseCase<List<PlaceSuggestion>, SearchPlacesParams> {
  const SearchPlaces(this._repository);

  final PlacesRepository _repository;

  @override
  Future<Either<Failure, List<PlaceSuggestion>>> call(
    SearchPlacesParams params,
  ) {
    return _repository.search(
      params.query,
      sessionToken: params.sessionToken,
      nearLatitude: params.nearLatitude,
      nearLongitude: params.nearLongitude,
    );
  }
}

class SearchPlacesParams extends Equatable {
  const SearchPlacesParams({
    required this.query,
    required this.sessionToken,
    this.nearLatitude,
    this.nearLongitude,
  });

  final String query;

  /// Groups one search session's requests for Google billing.
  final String sessionToken;
  final double? nearLatitude;
  final double? nearLongitude;

  @override
  List<Object?> get props => [query, sessionToken, nearLatitude, nearLongitude];
}
