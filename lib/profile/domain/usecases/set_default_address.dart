import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/saved_address.dart';
import '../repositories/profile_repository.dart';

/// `set_default_address(addressId)` → refreshed address list.
class SetDefaultAddress implements UseCase<List<SavedAddress>, String> {
  const SetDefaultAddress(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Either<Failure, List<SavedAddress>>> call(String addressId) =>
      _repository.setDefaultAddress(addressId);
}
