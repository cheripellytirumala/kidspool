import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../repositories/messages_repository.dart';

/// Marks a group's messages as read (`mark_ride_group_read`).
class MarkGroupRead implements UseCase<Unit, String> {
  const MarkGroupRead(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String params) =>
      _repository.markGroupRead(params);
}
