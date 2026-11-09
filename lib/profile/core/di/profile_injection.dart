import 'package:get_it/get_it.dart';

import '../../data/data_sources/local/profile_local_data_source.dart';
import '../../data/data_sources/remote/profile_remote_data_source.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/add_saved_address.dart';
import '../../domain/usecases/change_ride_mode.dart';
import '../../domain/usecases/delete_saved_address.dart';
import '../../domain/usecases/get_profile_overview.dart';
import '../../domain/usecases/set_default_address.dart';
import '../../domain/usecases/sign_out.dart';
import '../../presentation/providers/profile_provider.dart';

/// Registers everything owned by the Profile group.
/// Called from `lib/common/core/di/injection_container.dart`.
///
/// Reuses the shared `AccountRepository` (get_my_status, sign out) and the
/// Kids group's `KidsRepository` (get_my_kids + signed photo URLs).
void registerProfileDependencies(GetIt sl) {
  sl
    // Data sources
    ..registerLazySingleton<ProfileRemoteDataSource>(
      () => ProfileRemoteDataSourceImpl(apiClient: sl(), tokenProvider: sl()),
    )
    ..registerLazySingleton<ProfileLocalDataSource>(
      () => ProfileLocalDataSourceImpl(sl()),
    )
    // Repository
    ..registerLazySingleton<ProfileRepository>(
      () =>
          ProfileRepositoryImpl(remoteDataSource: sl(), localDataSource: sl()),
    )
    // Use cases
    ..registerLazySingleton<GetProfileOverview>(
      () => GetProfileOverview(
        profile: sl(),
        account: sl(),
        kids: sl(),
        messages: sl(),
      ),
    )
    ..registerLazySingleton<ChangeRideMode>(() => ChangeRideMode(sl()))
    ..registerLazySingleton<AddSavedAddress>(() => AddSavedAddress(sl()))
    ..registerLazySingleton<SetDefaultAddress>(() => SetDefaultAddress(sl()))
    ..registerLazySingleton<DeleteSavedAddress>(() => DeleteSavedAddress(sl()))
    ..registerLazySingleton<SignOut>(() => SignOut(sl()))
    // Providers: per-screen state.
    ..registerFactory<ProfileProvider>(
      () => ProfileProvider(
        getOverview: sl(),
        changeRideMode: sl(),
        addAddress: sl(),
        setDefaultAddress: sl(),
        deleteAddress: sl(),
        signOut: sl(),
      ),
    );
}
