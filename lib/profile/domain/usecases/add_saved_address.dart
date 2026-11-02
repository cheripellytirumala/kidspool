import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../../../common/domain/entities/picked_address.dart';
import '../entities/saved_address.dart';
import '../repositories/profile_repository.dart';

class AddAddressParams extends Equatable {
  const AddAddressParams({
    required this.address,
    required this.label,
    this.isDefault = false,
  });

  final PickedAddress address;
  final String label;
  final bool isDefault;

  @override
  List<Object?> get props => [address, label, isDefault];
}

/// `add_address` → refreshed address list.
class AddSavedAddress implements UseCase<List<SavedAddress>, AddAddressParams> {
  const AddSavedAddress(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Either<Failure, List<SavedAddress>>> call(AddAddressParams params) {
    if (!params.address.isComplete) {
      return Future.value(
        const Left(
          ServerFailure(
            'Pick the address from the search so we know where it is.',
            code: 'missing_field',
          ),
        ),
      );
    }
    final label = params.label.trim();
    return _repository.addAddress(
      params.address,
      label: label.isEmpty ? 'Home' : label,
      isDefault: params.isDefault,
    );
  }
}
