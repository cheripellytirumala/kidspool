import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../../core/usecase/usecase.dart';
import '../entities/picked_address.dart';
import '../repositories/places_repository.dart';

/// Full address + coordinates of a search suggestion.
class GetPlaceAddress implements UseCase<PickedAddress, GetPlaceAddressParams> {
  const GetPlaceAddress(this._repository);

  final PlacesRepository _repository;

  @override
  Future<Either<Failure, PickedAddress>> call(GetPlaceAddressParams params) {
    return _repository.details(
      params.placeId,
      sessionToken: params.sessionToken,
    );
  }
}

class GetPlaceAddressParams extends Equatable {
  const GetPlaceAddressParams({
    required this.placeId,
    required this.sessionToken,
  });

  final String placeId;
  final String sessionToken;

  @override
  List<Object?> get props => [placeId, sessionToken];
}
