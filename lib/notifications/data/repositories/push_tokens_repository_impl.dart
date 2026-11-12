import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/error_handler.dart';
import '../../../common/core/error/failures.dart';
import '../../domain/repositories/push_tokens_repository.dart';
import '../data_sources/remote/push_tokens_remote_data_source.dart';

class PushTokensRepositoryImpl implements PushTokensRepository {
  const PushTokensRepositoryImpl({
    required PushTokensRemoteDataSource remoteDataSource,
  }) : _remote = remoteDataSource;

  final PushTokensRemoteDataSource _remote;

  @override
  Future<Either<Failure, bool>> register({
    required String token,
    required String platform,
  }) => ErrorHandler.guard(
    tag: 'PushTokens.register',
    () => _remote.register(token: token, platform: platform),
  );

  @override
  Future<Either<Failure, bool>> unregister(String token) => ErrorHandler.guard(
    tag: 'PushTokens.unregister',
    () => _remote.unregister(token),
  );
}
