import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../AskRide/core/di/ask_ride_injection.dart';
import '../../Auth/core/di/auth_injection.dart';
import '../../data/data_sources/local/app_version_local_data_source.dart';
import '../../data/data_sources/remote/app_version_remote_data_source.dart';
import '../../data/repositories/app_version_repository_impl.dart';
import '../../domain/repositories/app_version_repository.dart';
import '../../domain/usecases/get_app_version.dart';
import '../../presentation/providers/app_version_provider.dart';
import '../config/environment.dart';
import '../network/api_client.dart';
import '../network/auth_token_provider.dart';
import '../network/dio_client.dart';
import '../utils/logger.dart';

/// Global service locator.
final GetIt sl = GetIt.instance;

/// Composition root. Call once in `main()` before `runApp`.
Future<void> initDependencies({EnvConfig? config}) async {
  final env = config ?? EnvConfig.fromDartDefine();
  AppLogger.configure(enabled: env.enableLogging);

  await _registerCore(env);
  _registerAppVersion();

  // Feature groups
  registerAuthDependencies(sl);
  registerAskRideDependencies(sl);
}

Future<void> _registerCore(EnvConfig env) async {
  final preferences = await SharedPreferences.getInstance();

  sl
    ..registerSingleton<EnvConfig>(env)
    ..registerSingleton<SharedPreferences>(preferences)
    ..registerLazySingleton<AuthTokenProvider>(InMemoryAuthTokenProvider.new)
    ..registerLazySingleton<Dio>(
      () => DioClient.create(config: sl(), tokenProvider: sl()),
    )
    ..registerLazySingleton<ApiClient>(() => ApiClient(sl()));
}

void _registerAppVersion() {
  sl
    // Data sources
    ..registerLazySingleton<AppVersionRemoteDataSource>(
      () => AppVersionRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<AppVersionLocalDataSource>(
      () => AppVersionLocalDataSourceImpl(sl()),
    )
    // Repository
    ..registerLazySingleton<AppVersionRepository>(
      () => AppVersionRepositoryImpl(
        remoteDataSource: sl(),
        localDataSource: sl(),
      ),
    )
    // Use cases
    ..registerLazySingleton<GetAppVersion>(() => GetAppVersion(sl()))
    // Providers
    ..registerFactory<AppVersionProvider>(
      () => AppVersionProvider(getAppVersion: sl()),
    );
}
