import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/ride_request.dart';
import '../repositories/messages_repository.dart';

/// F24a · Requests: own open requests with offers + requests sent to the user.
class GetRequestsInbox implements UseCase<RequestsInbox, NoParams> {
  const GetRequestsInbox(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, RequestsInbox>> call(NoParams params) =>
      _repository.getRequestsInbox();
}
