import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/ride_mode.dart';
import '../repositories/profile_repository.dart';

/// "How you use KidPool": get rides only, or get & give rides.
class ChangeRideMode implements UseCase<RideMode, RideMode> {
  const ChangeRideMode(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Either<Failure, RideMode>> call(RideMode mode) =>
      _repository.setRideMode(mode);
}
