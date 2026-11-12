import 'package:fpdart/fpdart.dart';

import '../../core/constants/api_constants.dart';
import '../../core/error/error_handler.dart';
import '../../core/error/failures.dart';
import '../../core/network/api_client.dart';
import '../../core/network/auth_token_provider.dart';
import '../../domain/entities/my_status.dart';
import '../../presentation/state/nav_badges.dart';
import '../../domain/repositories/account_repository.dart';
import '../models/my_status_model.dart';

class AccountRepositoryImpl implements AccountRepository {
  const AccountRepositoryImpl({
    required ApiClient apiClient,
    required AuthTokenProvider tokenProvider,
    Future<void> Function()? beforeSignOut,
  }) : _api = apiClient,
       _tokens = tokenProvider,
       _beforeSignOut = beforeSignOut;

  final ApiClient _api;
  final AuthTokenProvider _tokens;

  /// Runs while the session is still valid (e.g. unregistering this
  /// device's push token). Its errors never block signing out.
  final Future<void> Function()? _beforeSignOut;

  @override
  bool get isSignedIn => _tokens.hasSession;

  @override
  Future<Either<Failure, MyStatus>> getMyStatus() => ErrorHandler.guard(
    tag: 'Account.getMyStatus',
    () => _api.rpc(ApiConstants.getMyStatus, parser: MyStatusModel.fromJson),
  );

  @override
  Future<void> signOut() async {
    try {
      await _beforeSignOut?.call();
    } catch (_) {
      // Best effort.
    }
    // The next account must not see this one's unread count.
    NavBadges.instance.clear();
    await _tokens.clear();
  }
}
