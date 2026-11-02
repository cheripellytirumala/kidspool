import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../../core/usecase/usecase.dart';
import '../entities/picked_address.dart';
import '../repositories/places_repository.dart';

/// Address under the map pin; with no coordinates, the device's location.
class ResolveMapPosition
    implements UseCase<PickedAddress, ResolveMapPositionParams> {
  const ResolveMapPosition(this._repository);

  final PlacesRepository _repository;

  @override
  Future<Either<Failure, PickedAddress>> call(ResolveMapPositionParams params) {
    final lat = params.latitude;
    final lng = params.longitude;
    if (lat == null || lng == null) return _repository.currentLocation();
    return _repository.addressAt(lat, lng);
  }
}

class ResolveMapPositionParams extends Equatable {
  const ResolveMapPositionParams({this.latitude, this.longitude});

  /// Use the device's current location.
  const ResolveMapPositionParams.current() : latitude = null, longitude = null;

  final double? latitude;
  final double? longitude;

  @override
  List<Object?> get props => [latitude, longitude];
}
