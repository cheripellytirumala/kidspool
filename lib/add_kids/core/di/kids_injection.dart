import 'package:get_it/get_it.dart';

import '../../data/data_sources/local/kids_local_data_source.dart';
import '../../data/data_sources/local/place_catalog.dart';
import '../../data/data_sources/remote/kids_remote_data_source.dart';
import '../../data/repositories/kids_repository_impl.dart';
import '../../domain/repositories/kids_repository.dart';
import '../../presentation/providers/add_child_form_provider.dart';
import '../../presentation/providers/kids_provider.dart';
import '../../presentation/providers/place_assignment_provider.dart';
import '../../presentation/providers/place_search_provider.dart';

/// Registers everything owned by the Kids feature group.
/// Called from `lib/core/di/injection_container.dart`.
void registerKidsDependencies(GetIt sl) {
  // Data sources
  sl
    ..registerLazySingleton<KidsRemoteDataSource>(
      () => KidsRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<KidsLocalDataSource>(
      () => KidsLocalDataSourceImpl(sl()),
    )
    ..registerLazySingleton<PlaceCatalog>(PlaceCatalog.new)
    // Repository
    ..registerLazySingleton<KidsRepository>(
      () => KidsRepositoryImpl(remoteDataSource: sl(), localDataSource: sl()),
    )
    // Use cases (registerLazySingleton per use case)
    // Providers
    // Flow state shared by F06–F12: one instance for the whole flow.
    ..registerLazySingleton<KidsProvider>(
      () => KidsProvider(repository: sl(), account: sl(), catalog: sl()),
    )
    // Per-screen state: factory, so each screen gets fresh state.
    ..registerFactory<AddChildFormProvider>(
      () => AddChildFormProvider(sl(), sl()),
    )
    ..registerFactory<PlaceSearchProvider>(
      () => PlaceSearchProvider(sl(), sl()),
    )
    ..registerFactory<PlaceAssignmentProvider>(
      () => PlaceAssignmentProvider(sl()),
    );
}
