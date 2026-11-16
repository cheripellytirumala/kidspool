import 'package:fpdart/fpdart.dart';
import 'package:get_it/get_it.dart';
import 'package:kidspool/common/core/error/failures.dart';
import 'package:kidspool/safety/data/safety_repository.dart';
import 'package:kidspool/safety/domain/safety_entities.dart';
import 'package:kidspool/safety/presentation/blocked_users.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory report / block backend.
class FakeSafetyRepository implements SafetyRepository {
  final List<String> blocked = [];
  final List<(String, ReportReason, bool)> reports = [];
  List<BlockedUser> serverBlocks = const [];
  Failure? failWith;

  Either<Failure, T> _result<T>(T value) =>
      failWith == null ? Right(value) : Left(failWith!);

  @override
  Future<Either<Failure, void>> block(String userId) async {
    if (failWith == null) {
      blocked.add(userId);
      if (!serverBlocks.any((u) => u.id == userId)) {
        serverBlocks = [...serverBlocks, BlockedUser(id: userId, name: userId)];
      }
    }
    return _result(null);
  }

  @override
  Future<Either<Failure, void>> unblock(String userId) async {
    if (failWith == null) {
      blocked.remove(userId);
      serverBlocks = [
        for (final u in serverBlocks)
          if (u.id != userId) u,
      ];
    }
    return _result(null);
  }

  @override
  Future<Either<Failure, List<BlockedUser>>> blocks() async =>
      _result(serverBlocks);

  @override
  Future<Either<Failure, void>> deleteAccount() async => _result(null);

  @override
  Future<Either<Failure, void>> report({
    required String userId,
    required ReportReason reason,
    String? details,
    ReportContext? context,
    String? contextId,
    String? messageId,
    bool alsoBlock = false,
  }) async {
    if (failWith == null) reports.add((userId, reason, alsoBlock));
    return _result(null);
  }
}

/// Registers [BlockedUsers] (and its repository) for widget tests.
Future<FakeSafetyRepository> registerFakeSafety(
  GetIt sl, {
  String userId = 'me',
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = FakeSafetyRepository();
  sl
    ..registerSingleton<SafetyRepository>(repo)
    ..registerSingleton<BlockedUsers>(
      BlockedUsers(repository: repo, preferences: prefs, userId: () => userId),
    );
  return repo;
}
