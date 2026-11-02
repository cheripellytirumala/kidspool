import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/saved_address.dart';
import '../repositories/profile_repository.dart';

/// `delete_address(addressId)` → refreshed address list.
class DeleteSavedAddress implements UseCase<List<SavedAddress>, String> {
  const DeleteSavedAddress(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Either<Failure, List<SavedAddress>>> call(String addressId) =>
      _repository.deleteAddress(addressId);
}
