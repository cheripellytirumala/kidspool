import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../add_kids/presentation/providers/kids_provider.dart';
import '../../../ask_ride/core/di/ask_ride_injection.dart';
import '../../../ask_ride/presentation/providers/ask_ride_provider.dart';
import '../../../auth/presentation/providers/auth_flow_provider.dart';
import '../../../home/presentation/providers/home_provider.dart';
import '../../../auth/core/di/auth_injection.dart';
import '../../../home/core/di/home_injection.dart';
import '../../../add_kids/core/di/kids_injection.dart';
import '../../../messages/core/di/messages_injection.dart';
import '../../../notifications/core/di/notifications_injection.dart';
import '../../../notifications/core/services/ride_notifications.dart';
import '../../../onboarding/core/di/onboarding_injection.dart';
import '../../../profile/core/di/profile_injection.dart';
import '../../../rides/core/di/rides_injection.dart';
import '../../../ride_tracking/core/di/ride_tracking_injection.dart';
import '../../../ride_tracking/domain/repositories/ride_location_sharing.dart';
import '../../presentation/widgets/approval_gate.dart';
import '../config/environment.dart';
import '../../data/data_sources/remote/places_remote_data_source.dart';
import '../../data/repositories/places_repository_impl.dart';
import '../../domain/repositories/places_repository.dart';
import '../../domain/usecases/get_place_address.dart';
import '../../domain/usecases/resolve_map_position.dart';
import '../../domain/usecases/search_places.dart';
import '../../presentation/providers/map_address_picker_provider.dart';
import '../config/maps_config.dart';
import '../network/api_client.dart';
import '../network/auth_token_provider.dart';
import '../network/dio_client.dart';
import '../services/location_service.dart';
import '../services/photo_picker.dart';
import '../services/time_zone_service.dart';
import '../../data/repositories/account_repository_impl.dart';
import '../../domain/repositories/account_repository.dart';
import '../utils/logger.dart';

/// Global service locator.
final GetIt sl = GetIt.instance;

/// Composition root. Call once in `main()` before `runApp`.
Future<void> initDependencies({EnvConfig? config}) async {
  final env = config ?? EnvConfig.fromDartDefine();
  AppLogger.configure(enabled: env.enableLogging);

  await _registerCore(env);
  _registerPlaces();

  // Feature groups
  registerOnboardingDependencies(sl);
  registerAuthDependencies(sl);
  registerKidsDependencies(sl);
  registerHomeDependencies(sl);
  registerAskRideDependencies(sl);
  registerProfileDependencies(sl);
  registerRideTrackingDependencies(sl);
  registerMessagesDependencies(sl);
  registerNotificationsDependencies(sl);
  registerRidesDependencies(sl);
}

Future<void> _registerCore(EnvConfig env) async {
  final preferences = await SharedPreferences.getInstance();

  sl
    ..registerSingleton<EnvConfig>(env)
    ..registerSingleton<SharedPreferences>(preferences)
    ..registerLazySingleton<AuthTokenProvider>(
      () => PrefsAuthTokenProvider(sl()),
    )
    ..registerLazySingleton<Dio>(
      () => DioClient.create(config: sl(), tokenProvider: sl()),
    )
    ..registerLazySingleton<ApiClient>(() => ApiClient(sl()))
    // Device services (camera, location, time zone)
    ..registerLazySingleton<PhotoPicker>(PhotoPicker.new)
    ..registerLazySingleton<LocationService>(LocationService.new)
    ..registerLazySingleton<TimeZoneService>(TimeZoneService.new)
    // Signed-in account (get_my_status), shared by every feature
    ..registerLazySingleton<AccountRepository>(
      () => AccountRepositoryImpl(
        apiClient: sl(),
        tokenProvider: sl(),
        // Unregister this device's push token while the session is valid.
        beforeSignOut: () => sl.isRegistered<RideNotifications>()
            ? sl<RideNotifications>().onSignOut()
            : Future<void>.value(),
      ),
    );
}

/// Google Places search + map address picker (shared by every group).
void _registerPlaces() {
  sl
    ..registerLazySingleton<PlacesRemoteDataSource>(
      // Own client: Google must not receive the app's auth headers.
      () => PlacesRemoteDataSourceImpl(
        Dio(
          BaseOptions(
            baseUrl: MapsConfig.placesBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            responseType: ResponseType.json,
          ),
        ),
      ),
    )
    ..registerLazySingleton<PlacesRepository>(
      () => PlacesRepositoryImpl(remoteDataSource: sl(), locationService: sl()),
    )
    ..registerLazySingleton<SearchPlaces>(() => SearchPlaces(sl()))
    ..registerLazySingleton<GetPlaceAddress>(() => GetPlaceAddress(sl()))
    ..registerLazySingleton<ResolveMapPosition>(() => ResolveMapPosition(sl()))
    ..registerFactory<MapAddressPickerProvider>(
      () => MapAddressPickerProvider(
        searchPlaces: sl(),
        getPlaceAddress: sl(),
        resolveMapPosition: sl(),
      ),
    );
}

/// Drops state that belongs to the signed-in user (kids, ride draft, home
/// dashboard, sign-up flow) so the next account starts clean. Call after
/// signing out, before navigating to sign-in.
void resetSessionState() {
  ApprovalGate.reset();
  // Stop sharing the driver's location for the previous account.
  if (sl.isRegistered<RideLocationSharing>()) sl<RideLocationSharing>().stop();
  for (final reset in <void Function()>[
    () => sl.resetLazySingleton<KidsProvider>(),
    () => sl.resetLazySingleton<AuthFlowProvider>(),
    () => sl.resetLazySingleton<AskRideProvider>(),
    () => sl.resetLazySingleton<HomeProvider>(),
  ]) {
    reset();
  }
}
