import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/chat_person.dart';
import '../repositories/messages_repository.dart';

/// Parent approves or declines a Ride Partner's offer (`respond_to_offer`).
/// Returns the confirmed Ride Partner on approve.
class RespondToOffer implements UseCase<ChatPerson?, RespondToOfferParams> {
  const RespondToOffer(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, ChatPerson?>> call(RespondToOfferParams params) =>
      _repository.respondToOffer(params.offerId, approve: params.approve);
}

class RespondToOfferParams extends Equatable {
  const RespondToOfferParams({required this.offerId, required this.approve});

  final String offerId;
  final bool approve;

  @override
  List<Object?> get props => [offerId, approve];
}
