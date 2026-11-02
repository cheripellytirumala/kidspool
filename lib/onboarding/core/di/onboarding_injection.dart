import 'package:get_it/get_it.dart';

import '../../data/data_sources/local/app_version_local_data_source.dart';
import '../../data/data_sources/remote/app_version_remote_data_source.dart';
import '../../data/repositories/app_version_repository_impl.dart';
import '../../domain/repositories/app_version_repository.dart';
import '../../domain/usecases/get_app_version.dart';
import '../../presentation/providers/app_version_provider.dart';

/// Registers everything owned by the Onboarding group (splash + app version).
/// Called from `lib/common/core/di/injection_container.dart`.
void registerOnboardingDependencies(GetIt sl) {
  sl
    // Data sources
    ..registerLazySingleton<AppVersionRemoteDataSource>(
      () => AppVersionRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<AppVersionLocalDataSource>(
      () => AppVersionLocalDataSourceImpl(sl()),
    )
    // Repository
    ..registerLazySingleton<AppVersionRepository>(
      () => AppVersionRepositoryImpl(
        remoteDataSource: sl(),
        localDataSource: sl(),
      ),
    )
    // Use cases
    ..registerLazySingleton<GetAppVersion>(() => GetAppVersion(sl()))
    // Providers
    ..registerFactory<AppVersionProvider>(
      () => AppVersionProvider(getAppVersion: sl(), account: sl()),
    );
}
