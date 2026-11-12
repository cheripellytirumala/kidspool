import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/ride_ask.dart';
import '../entities/ride_group.dart';
import '../repositories/messages_repository.dart';

/// Posts a ride as a card in a group (`post_ride_ask`); the request is
/// created later, when a driver taps "I can help".
class PostRideAsk implements UseCase<GroupMessage, PostRideAskParams> {
  const PostRideAsk(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, GroupMessage>> call(PostRideAskParams params) =>
      _repository.postRideAsk(
        groupId: params.groupId,
        rides: params.rides,
        summary: params.summary,
      );
}

class PostRideAskParams extends Equatable {
  const PostRideAskParams({
    required this.groupId,
    required this.rides,
    required this.summary,
  });

  final String groupId;

  /// `create_ride_request` arguments, one map per day.
  final List<Map<String, dynamic>> rides;
  final String summary;

  @override
  List<Object?> get props => [groupId, rides, summary];
}

/// The ride cards in a group (`get_group_ride_asks`).
class GetGroupRideAsks implements UseCase<List<RideAsk>, String> {
  const GetGroupRideAsks(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, List<RideAsk>>> call(String groupId) =>
      _repository.getGroupRideAsks(groupId);
}

/// "I can help" on a ride card (`help_with_ride_ask`).
class HelpWithRideAsk implements UseCase<Unit, String> {
  const HelpWithRideAsk(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String askId) =>
      _repository.helpWithRideAsk(askId);
}
