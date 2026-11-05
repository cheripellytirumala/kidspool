import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/ride_request.dart';
import '../repositories/messages_repository.dart';

/// A request the user drives or was sent as a Ride Partner.
class GetDriveRequest implements UseCase<RideRequest, String> {
  const GetDriveRequest(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, RideRequest>> call(String params) =>
      _repository.getDriveRequest(params);
}
