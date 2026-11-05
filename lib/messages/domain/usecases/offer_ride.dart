import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/ride_request.dart';
import '../repositories/messages_repository.dart';

/// Ride Partner: "I can help" (`offer_ride`, this day).
class OfferRide implements UseCase<OfferOutcome, String> {
  const OfferRide(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, OfferOutcome>> call(String params) =>
      _repository.offerRide(params);
}
