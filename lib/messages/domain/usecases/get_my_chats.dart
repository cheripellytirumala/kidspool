import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/ride_chat.dart';
import '../repositories/messages_repository.dart';

/// F24 · Chats (`get_my_ride_chats`).
class GetMyChats implements UseCase<List<RideChat>, NoParams> {
  const GetMyChats(this._repository);

  final MessagesRepository _repository;

  @override
  Future<Either<Failure, List<RideChat>>> call(NoParams params) =>
      _repository.getMyChats();
}
