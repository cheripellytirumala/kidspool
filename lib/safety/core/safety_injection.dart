import 'package:get_it/get_it.dart';

import '../../common/core/network/auth_token_provider.dart';
import '../../feedback/feedback_repository.dart';
import '../data/safety_remote_data_source.dart';
import '../data/safety_repository.dart';
import '../presentation/blocked_users.dart';

/// Report / block / delete account.
void registerSafetyDependencies(GetIt sl) {
  sl
    ..registerLazySingleton<SafetyRemoteDataSource>(
      () => SafetyRemoteDataSource(sl()),
    )
    ..registerLazySingleton<SafetyRepository>(() => SafetyRepository(sl()))
    // Profile › Send feedback.
    ..registerLazySingleton<FeedbackRepository>(() => FeedbackRepository(sl()))
    ..registerLazySingleton<BlockedUsers>(
      () => BlockedUsers(
        repository: sl(),
        preferences: sl(),
        userId: () => sl<AuthTokenProvider>().session?.userId,
      ),
    );
}
