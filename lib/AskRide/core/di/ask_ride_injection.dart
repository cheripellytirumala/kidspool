import 'package:get_it/get_it.dart';

import '../../data/data_sources/local/ask_ride_local_data_source.dart';
import '../../data/data_sources/remote/ask_ride_remote_data_source.dart';
import '../../data/repositories/ask_ride_repository_impl.dart';
import '../../domain/repositories/ask_ride_repository.dart';
import '../../presentation/providers/ask_ride_provider.dart';

/// Registers everything owned by the AskRide feature group.
/// Called from `lib/core/di/injection_container.dart`.
void registerAskRideDependencies(GetIt sl) {
  // Data sources
  sl
    ..registerLazySingleton<AskRideRemoteDataSource>(
      () => AskRideRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<AskRideLocalDataSource>(
      () => AskRideLocalDataSourceImpl(sl()),
    )
    // Repository
    ..registerLazySingleton<AskRideRepository>(
      () =>
          AskRideRepositoryImpl(remoteDataSource: sl(), localDataSource: sl()),
    )
    // Use cases (registerLazySingleton per use case)
    // Providers: factory, so each screen subtree gets fresh state.
    ..registerFactory<AskRideProvider>(AskRideProvider.new);
}
