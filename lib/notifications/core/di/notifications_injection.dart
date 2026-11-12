import 'package:get_it/get_it.dart';

import '../../../common/domain/repositories/account_repository.dart';
import '../../../ride_tracking/domain/repositories/ride_alert_notifier.dart';
import '../../data/data_sources/remote/notifications_remote_data_source.dart';
import '../../data/data_sources/remote/push_tokens_remote_data_source.dart';
import '../../data/repositories/notifications_repository_impl.dart';
import '../../data/repositories/push_tokens_repository_impl.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../../domain/repositories/push_tokens_repository.dart';
import '../../presentation/providers/notifications_provider.dart';
import '../services/local_notifications.dart';
import '../services/push_messaging.dart';
import '../services/ride_notifications.dart';

/// Registers the Notifications feature (F25b) and S19 / S20 system
/// notifications (local + push).
void registerNotificationsDependencies(GetIt sl) {
  sl
    ..registerLazySingleton<NotificationsRemoteDataSource>(
      () => NotificationsRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<PushTokensRemoteDataSource>(
      () => PushTokensRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<NotificationsRepository>(
      () => NotificationsRepositoryImpl(
        remoteDataSource: sl(),
        preferences: sl(),
      ),
    )
    ..registerLazySingleton<PushTokensRepository>(
      () => PushTokensRepositoryImpl(remoteDataSource: sl()),
    )
    // Device services: one per app process.
    ..registerLazySingleton<LocalNotifications>(LocalNotificationsImpl.new)
    ..registerLazySingleton<PushMessaging>(FirebasePushMessaging.new)
    ..registerLazySingleton<RideNotifications>(
      () => RideNotifications(
        local: sl(),
        push: sl(),
        tokens: sl(),
        preferences: sl(),
        isSignedIn: () => sl<AccountRepository>().isSignedIn,
      ),
    )
    ..registerLazySingleton<RideAlertNotifier>(() => sl<RideNotifications>())
    // Fresh state for every visit.
    ..registerFactory<NotificationsProvider>(
      () => NotificationsProvider(repository: sl()),
    );
}
