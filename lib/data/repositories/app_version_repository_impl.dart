import 'package:fpdart/fpdart.dart';

import '../../core/error/error_handler.dart';
import '../../core/error/exceptions.dart';
import '../../core/error/failures.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/app_version.dart';
import '../../domain/repositories/app_version_repository.dart';
import '../../domain/usecases/get_app_version.dart';
import '../data_sources/local/app_version_local_data_source.dart';
import '../data_sources/remote/app_version_remote_data_source.dart';
import '../mappers/app_version_mapper.dart';

class AppVersionRepositoryImpl implements AppVersionRepository {
  const AppVersionRepositoryImpl({
    required AppVersionRemoteDataSource remoteDataSource,
    required AppVersionLocalDataSource localDataSource,
  }) : _remote = remoteDataSource,
       _local = localDataSource;

  final AppVersionRemoteDataSource _remote;
  final AppVersionLocalDataSource _local;

  @override
  Future<Either<Failure, AppVersion>> getAppVersion(
    GetAppVersionParams params,
  ) {
    return ErrorHandler.guard(tag: 'AppVersionRepository', () async {
      try {
        final model = await _remote.getAppVersion(params);
        await _cacheSilently(() => _local.cacheAppVersion(model));
        return model.toEntity();
      } on NetworkException catch (networkError) {
        // Offline: fall back to the last known config, else surface the
        // original network error.
        try {
          return (await _local.getCachedAppVersion()).toEntity();
        } on CacheException {
          throw networkError;
        }
      }
    });
  }

  Future<void> _cacheSilently(Future<void> Function() write) async {
    try {
      await write();
    } on CacheException catch (e) {
      AppLogger.warning(e.message, tag: 'AppVersionRepository');
    }
  }
}
