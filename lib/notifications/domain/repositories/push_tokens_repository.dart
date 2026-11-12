import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';

/// This device's push (FCM) token on the backend, so the `send-ride-push`
/// Edge Function can reach the signed-in parent.
abstract interface class PushTokensRepository {
  /// Right(false) when the backend has no `register_push_token` yet.
  Future<Either<Failure, bool>> register({
    required String token,
    required String platform,
  });

  /// Right(false) when the backend has no `unregister_push_token` yet.
  Future<Either<Failure, bool>> unregister(String token);
}
