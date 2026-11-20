import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../../../common/domain/entities/my_status.dart';
import '../repositories/profile_repository.dart';

/// Sets the user's optional gender (`null` clears it).
class ChangeGender implements UseCase<Gender?, Gender?> {
  const ChangeGender(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Either<Failure, Gender?>> call(Gender? gender) =>
      _repository.setGender(gender);
}
