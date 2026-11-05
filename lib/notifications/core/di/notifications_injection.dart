import 'package:get_it/get_it.dart';

import '../../data/data_sources/remote/notifications_remote_data_source.dart';
import '../../data/repositories/notifications_repository_impl.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../../presentation/providers/notifications_provider.dart';

/// Registers the Notifications feature (F25b).
void registerNotificationsDependencies(GetIt sl) {
  sl
    ..registerLazySingleton<NotificationsRemoteDataSource>(
      () => NotificationsRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<NotificationsRepository>(
      () => NotificationsRepositoryImpl(
        remoteDataSource: sl(),
        preferences: sl(),
      ),
    )
    // Fresh state for every visit.
    ..registerFactory<NotificationsProvider>(
      () => NotificationsProvider(repository: sl()),
    );
}
