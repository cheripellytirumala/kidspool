import 'package:fpdart/fpdart.dart';

import '../../core/constants/api_constants.dart';
import '../../core/error/error_handler.dart';
import '../../core/error/failures.dart';
import '../../core/network/api_client.dart';
import '../../core/network/auth_token_provider.dart';
import '../../domain/entities/my_status.dart';
import '../../domain/repositories/account_repository.dart';
import '../models/my_status_model.dart';

class AccountRepositoryImpl implements AccountRepository {
  const AccountRepositoryImpl({
    required ApiClient apiClient,
    required AuthTokenProvider tokenProvider,
  }) : _api = apiClient,
       _tokens = tokenProvider;

  final ApiClient _api;
  final AuthTokenProvider _tokens;

  @override
  bool get isSignedIn => _tokens.hasSession;

  @override
  Future<Either<Failure, MyStatus>> getMyStatus() => ErrorHandler.guard(
    tag: 'Account.getMyStatus',
    () => _api.rpc(ApiConstants.getMyStatus, parser: MyStatusModel.fromJson),
  );

  @override
  Future<void> signOut() => _tokens.clear();
}
