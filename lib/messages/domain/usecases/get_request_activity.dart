import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/ride_request.dart';
import '../repositories/messages_repository.dart';

/// How many families a request went to (`get_request_activity`).
class GetRequestActivity implements UseCase<RequestActivity, String> {
  const GetRequestActivity(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, RequestActivity>> call(String params) =>
      _repository.getRequestActivity(params);
}
