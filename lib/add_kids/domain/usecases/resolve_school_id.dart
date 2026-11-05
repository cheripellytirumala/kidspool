import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/place.dart';
import '../repositories/kids_repository.dart';

/// The `schools.id` to save for a picked school. Google results are turned
/// into a school row first (`school_from_place`); saved schools keep their
/// id.
class ResolveSchoolId implements UseCase<String, Place> {
  const ResolveSchoolId(this._repository);

  final KidsRepository _repository;

  @override
  Future<Either<Failure, String>> call(Place place) async {
    if (!place.isGooglePlace) return Right(place.id);
    return _repository.schoolFromPlace(place);
  }
}
