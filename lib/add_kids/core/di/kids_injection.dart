import 'package:get_it/get_it.dart';

import '../../data/data_sources/local/kids_local_data_source.dart';
import '../../data/data_sources/local/place_catalog.dart';
import '../../data/data_sources/remote/kids_remote_data_source.dart';
import '../../data/repositories/kids_repository_impl.dart';
import '../../domain/repositories/kids_repository.dart';
import '../../domain/usecases/get_home_location.dart';
import '../../domain/usecases/resolve_school_id.dart';
import '../../domain/usecases/search_kid_places.dart';
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
    // SearchKidPlaces / GetHomeLocation also use the shared PlacesRepository.
    ..registerLazySingleton<SearchKidPlaces>(() => SearchKidPlaces(sl()))
    ..registerLazySingleton<GetHomeLocation>(() => GetHomeLocation(sl(), sl()))
    ..registerLazySingleton<ResolveSchoolId>(() => ResolveSchoolId(sl()))
    // Providers
    // Flow state shared by F06–F12: one instance for the whole flow.
    ..registerLazySingleton<KidsProvider>(
      () => KidsProvider(
        repository: sl(),
        account: sl(),
        resolveSchoolId: sl(),
        catalog: sl(),
      ),
    )
    // Per-screen state: factory, so each screen gets fresh state.
    ..registerFactory<AddChildFormProvider>(
      () => AddChildFormProvider(sl(), sl()),
    )
    ..registerFactory<PlaceSearchProvider>(
      () => PlaceSearchProvider(searchPlaces: sl(), getHomeLocation: sl()),
    )
    ..registerFactory<PlaceAssignmentProvider>(
      () => PlaceAssignmentProvider(sl()),
    );
}
