import 'package:get_it/get_it.dart';

import '../../data/data_sources/local/home_local_data_source.dart';
import '../../data/data_sources/remote/home_remote_data_source.dart';
import '../../data/repositories/home_repository_impl.dart';
import '../../domain/repositories/home_repository.dart';
import '../../presentation/providers/families_near_you_provider.dart';
import '../../presentation/providers/home_provider.dart';

/// Registers everything owned by the Home feature group.
/// Called from `lib/core/di/injection_container.dart`.
void registerHomeDependencies(GetIt sl) {
  // Data sources
  sl
    ..registerLazySingleton<HomeRemoteDataSource>(
      () => HomeRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<HomeLocalDataSource>(
      () => HomeLocalDataSourceImpl(sl()),
    )
    // Repository
    ..registerLazySingleton<HomeRepository>(
      () => HomeRepositoryImpl(remoteDataSource: sl(), localDataSource: sl()),
    )
    // Use cases (registerLazySingleton per use case)
    // Providers
    // Shared across screens (role survives navigation).
    ..registerLazySingleton<HomeProvider>(
      () => HomeProvider(repository: sl(), account: sl(), preferences: sl()),
    )
    // Per-screen state: fresh for every "Families near you" visit.
    ..registerFactory<FamiliesNearYouProvider>(FamiliesNearYouProvider.new);
}
