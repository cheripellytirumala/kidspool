import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../repositories/driver_availability_repository.dart';

/// Home "Available" switch as the server has it (`get_driver_available`),
/// so the switch matches the green dot other parents see.
class GetDriverAvailable implements UseCase<bool, NoParams> {
  const GetDriverAvailable(this._repository);

  final DriverAvailabilityRepository _repository;

  @override
  Future<Either<Failure, bool>> call(NoParams params) =>
      _repository.getAvailable();
}
