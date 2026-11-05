import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../repositories/messages_repository.dart';

/// Ride Partner takes back a pending offer (`withdraw_offer`).
class WithdrawOffer implements UseCase<Unit, String> {
  const WithdrawOffer(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String params) =>
      _repository.withdrawOffer(params);
}
