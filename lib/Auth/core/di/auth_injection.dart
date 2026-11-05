import 'package:get_it/get_it.dart';

import '../../data/data_sources/local/auth_local_data_source.dart';
import '../../data/data_sources/local/license_reader.dart';
import '../../data/data_sources/remote/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../presentation/providers/auth_flow_provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/otp_provider.dart';
import '../../presentation/providers/review_status_provider.dart';
import '../../presentation/providers/scan_id_provider.dart';

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
    // On-device ML Kit license reader (no network).
    ..registerLazySingleton<LicenseReader>(MlKitLicenseReader.new)
    // Repository
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        remoteDataSource: sl(),
        localDataSource: sl(),
        tokenProvider: sl(),
      ),
    )
    // Providers: factory, so each screen subtree gets fresh state.
    ..registerFactory<AuthProvider>(AuthProvider.new)
    ..registerFactory<OtpProvider>(
      () => OtpProvider(repository: sl(), account: sl(), flow: sl()),
    )
    ..registerFactory<ScanIdProvider>(ScanIdProvider.new)
    ..registerFactory<ReviewStatusProvider>(() => ReviewStatusProvider(sl()))
    // Sign-up flow state shared by S03 → V3.
    ..registerLazySingleton<AuthFlowProvider>(
      () => AuthFlowProvider(
        repository: sl(),
        location: sl(),
        photos: sl(),
        preferences: sl(),
        licenseReader: sl(),
      ),
    );
}
