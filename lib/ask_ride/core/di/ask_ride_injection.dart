import 'package:get_it/get_it.dart';

import '../../data/data_sources/local/ask_ride_local_data_source.dart';
import '../../data/data_sources/remote/ask_ride_remote_data_source.dart';
import '../../data/repositories/ask_ride_repository_impl.dart';
import '../../domain/repositories/ask_ride_repository.dart';
import '../../domain/usecases/add_saved_place.dart';
import '../../domain/usecases/get_ride_options.dart';
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
      () => AskRideRepositoryImpl(
        remoteDataSource: sl(),
        localDataSource: sl(),
        kidsRepository: sl(),
      ),
    )
    // Use cases
    ..registerLazySingleton<GetRideOptions>(() => GetRideOptions(sl()))
    ..registerLazySingleton<AddSavedPlace>(() => AddSavedPlace(sl()))
    // Provider: lazy singleton so the ride request draft survives the
    // families screen (F19) and the "Message sent" screen (F20). Screens
    // expose it with `ChangeNotifierProvider.value(value: sl<AskRideProvider>())`.
    ..registerLazySingleton<AskRideProvider>(
      () => AskRideProvider(
        getRideOptions: sl(),
        addSavedPlace: sl(),
        repository: sl(),
        timeZone: sl(),
      ),
    );
}
