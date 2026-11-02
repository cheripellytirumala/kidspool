import 'package:fpdart/fpdart.dart';

import '../../core/error/error_handler.dart';
import '../../core/error/failures.dart';
import '../../core/services/location_service.dart';
import '../../domain/entities/picked_address.dart';
import '../../domain/entities/place_suggestion.dart';
import '../../domain/repositories/places_repository.dart';
import '../data_sources/remote/places_remote_data_source.dart';

class PlacesRepositoryImpl implements PlacesRepository {
  const PlacesRepositoryImpl({
    required PlacesRemoteDataSource remoteDataSource,
    required LocationService locationService,
  }) : _remote = remoteDataSource,
       _location = locationService;

  final PlacesRemoteDataSource _remote;
  final LocationService _location;

  @override
  Future<Either<Failure, List<PlaceSuggestion>>> search(
    String query, {
    required String sessionToken,
    double? nearLatitude,
    double? nearLongitude,
  }) {
    return ErrorHandler.guard(tag: 'PlacesRepository.search', () async {
      final models = await _remote.autocomplete(
        query,
        sessionToken: sessionToken,
        nearLatitude: nearLatitude,
        nearLongitude: nearLongitude,
      );
      return models.map((m) => m.toEntity()).toList(growable: false);
    });
  }

  @override
  Future<Either<Failure, PickedAddress>> details(
    String placeId, {
    required String sessionToken,
  }) {
    return ErrorHandler.guard(tag: 'PlacesRepository.details', () async {
      final model = await _remote.details(placeId, sessionToken: sessionToken);
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, PickedAddress>> addressAt(
    double latitude,
    double longitude,
  ) {
    return ErrorHandler.guard(tag: 'PlacesRepository.addressAt', () async {
      return _toPicked(await _location.addressAt(latitude, longitude));
    });
  }

  @override
  Future<Either<Failure, PickedAddress>> currentLocation() {
    return ErrorHandler.guard(
      tag: 'PlacesRepository.currentLocation',
      () async {
        return _toPicked(await _location.currentAddress());
      },
    );
  }

  PickedAddress _toPicked(ResolvedAddress a) => PickedAddress(
    latitude: a.latitude,
    longitude: a.longitude,
    street: a.street,
    city: a.city,
    stateCode: a.stateCode,
    zip: a.zip,
    formatted: [
      a.street,
      a.city,
      [a.stateCode, a.zip].where((p) => p.isNotEmpty).join(' '),
    ].where((p) => p.isNotEmpty).join(', '),
  );
}
