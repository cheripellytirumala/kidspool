import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../../../common/domain/entities/picked_address.dart';
import '../entities/saved_place.dart';
import '../repositories/ask_ride_repository.dart';

/// Saves a map-picked address; returns the refreshed saved places.
class AddSavedPlace implements UseCase<List<SavedPlace>, AddSavedPlaceParams> {
  const AddSavedPlace(this._repository);

  final AskRideRepository _repository;

  @override
  Future<Either<Failure, List<SavedPlace>>> call(AddSavedPlaceParams params) {
    return _repository.addSavedPlace(params.address, label: params.label);
  }
}

class AddSavedPlaceParams extends Equatable {
  const AddSavedPlaceParams({required this.address, this.label = 'Saved'});

  final PickedAddress address;

  /// Shown before the street, e.g. `Saved · 24 Maple St`.
  final String label;

  @override
  List<Object?> get props => [address, label];
}
