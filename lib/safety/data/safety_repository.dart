import 'package:fpdart/fpdart.dart';

import '../../common/core/error/error_handler.dart';
import '../../common/core/error/failures.dart';
import '../domain/safety_entities.dart';
import 'safety_remote_data_source.dart';

/// Report, block and delete-account calls as `Either`.
class SafetyRepository {
  const SafetyRepository(this._remote);

  final SafetyRemoteDataSource _remote;

  Future<Either<Failure, void>> report({
    required String userId,
    required ReportReason reason,
    String? details,
    ReportContext? context,
    String? contextId,
    String? messageId,
    bool alsoBlock = false,
  }) => ErrorHandler.guard(
    tag: 'Safety.report',
    () => _remote.report(
      userId: userId,
      reason: reason,
      details: details,
      context: context,
      contextId: contextId,
      messageId: messageId,
      alsoBlock: alsoBlock,
    ),
  );

  Future<Either<Failure, void>> block(String userId) =>
      ErrorHandler.guard(tag: 'Safety.block', () => _remote.block(userId));

  Future<Either<Failure, void>> unblock(String userId) =>
      ErrorHandler.guard(tag: 'Safety.unblock', () => _remote.unblock(userId));

  Future<Either<Failure, List<BlockedUser>>> blocks() =>
      ErrorHandler.guard(tag: 'Safety.blocks', _remote.blocks);

  Future<Either<Failure, void>> deleteAccount() =>
      ErrorHandler.guard(tag: 'Safety.deleteAccount', _remote.deleteAccount);
}
