import 'package:get_it/get_it.dart';

import '../../data/data_sources/local/ride_location_data_source.dart';
import '../../data/data_sources/remote/ride_alerts_remote_data_source.dart';
import '../../data/data_sources/remote/ride_tracking_remote_data_source.dart';
import '../../data/repositories/ride_alerts_repository_impl.dart';
import '../../data/repositories/ride_tracking_repository_impl.dart';
import '../../data/services/ride_location_reporter.dart';
import '../../domain/repositories/ride_alerts_repository.dart';
import '../../domain/repositories/ride_location_sharing.dart';
import '../../domain/repositories/ride_tracking_repository.dart';
import '../../domain/usecases/complete_ride.dart';
import '../../domain/usecases/get_ride_alerts.dart';
import '../../domain/usecases/get_ride_tracking.dart';
import '../../domain/usecases/mark_picked_up.dart';
import '../../domain/usecases/say_thank_you.dart';
import '../../domain/usecases/start_ride.dart';
import '../../domain/usecases/start_sharing_ride_location.dart';
import '../../domain/usecases/stop_sharing_ride_location.dart';
import '../../domain/usecases/trigger_ride_sos.dart';
import '../../presentation/providers/live_tracking_provider.dart';
import '../../presentation/providers/ride_alerts_provider.dart';
import '../../presentation/providers/ride_completed_provider.dart';

/// Registers everything owned by the RideTracking group.
/// Called from `lib/common/core/di/injection_container.dart`.
void registerRideTrackingDependencies(GetIt sl) {
  sl
    // Data sources
    ..registerLazySingleton<RideTrackingRemoteDataSource>(
      () => RideTrackingRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<RideAlertsRemoteDataSource>(
      () => RideAlertsRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<RideLocationDataSource>(
      RideLocationDataSourceImpl.new,
    )
    // Repositories / services
    ..registerLazySingleton<RideTrackingRepository>(
      () => RideTrackingRepositoryImpl(
        remoteDataSource: sl(),
        locationDataSource: sl(),
      ),
    )
    ..registerLazySingleton<RideAlertsRepository>(
      () =>
          RideAlertsRepositoryImpl(remoteDataSource: sl(), tokenProvider: sl()),
    )
    // One GPS reporter for the app process (one ride at a time).
    ..registerLazySingleton<RideLocationSharing>(
      () => RideLocationReporter(location: sl(), tracking: sl()),
    )
    // Use cases
    ..registerLazySingleton<GetRideTracking>(() => GetRideTracking(sl()))
    ..registerLazySingleton<StartRide>(() => StartRide(sl()))
    ..registerLazySingleton<MarkPickedUp>(() => MarkPickedUp(sl()))
    ..registerLazySingleton<CompleteRide>(() => CompleteRide(sl()))
    ..registerLazySingleton<TriggerRideSos>(() => TriggerRideSos(sl()))
    ..registerLazySingleton<SayThankYou>(() => SayThankYou(sl()))
    ..registerLazySingleton<GetRideAlerts>(() => GetRideAlerts(sl()))
    ..registerLazySingleton<StartSharingRideLocation>(
      () => StartSharingRideLocation(sl()),
    )
    ..registerLazySingleton<StopSharingRideLocation>(
      () => StopSharingRideLocation(sl()),
    )
    // Providers: one per screen / host instance.
    ..registerFactory<LiveTrackingProvider>(
      () => LiveTrackingProvider(
        getRideTracking: sl(),
        startRide: sl(),
        markPickedUp: sl(),
        completeRide: sl(),
        triggerSos: sl(),
        startSharing: sl(),
        stopSharing: sl(),
      ),
    )
    ..registerFactory<RideCompletedProvider>(
      () => RideCompletedProvider(getRideTracking: sl(), sayThankYou: sl()),
    )
    ..registerFactory<RideAlertsProvider>(
      () => RideAlertsProvider(getRideAlerts: sl()),
    );
}
