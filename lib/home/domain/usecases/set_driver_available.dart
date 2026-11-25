import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../repositories/driver_availability_repository.dart';

/// Home "Available" switch (`set_driver_available`): while off, the driver
/// gets no new ride requests. Booked rides are unaffected.
class SetDriverAvailable implements UseCase<bool, bool> {
  const SetDriverAvailable(this._repository);

  final DriverAvailabilityRepository _repository;

  @override
  Future<Either<Failure, bool>> call(bool available) =>
      _repository.setAvailable(available);
}
