import 'package:get_it/get_it.dart';

import '../../data/data_sources/local/auth_local_data_source.dart';
import '../../data/data_sources/remote/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../presentation/providers/auth_provider.dart';

/// Registers everything owned by the Auth feature group.
/// Called from `lib/core/di/injection_container.dart`.
void registerAuthDependencies(GetIt sl) {
  // Data sources
  sl
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<AuthLocalDataSource>(
      () => AuthLocalDataSourceImpl(sl()),
    )
    // Repository
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(remoteDataSource: sl(), localDataSource: sl()),
    )
    // Use cases (registerLazySingleton per use case)
    // Providers: factory, so each screen subtree gets fresh state.
    ..registerFactory<AuthProvider>(AuthProvider.new);
}
