import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../common/core/error/error_handler.dart';
import '../../../common/core/error/exceptions.dart';
import '../../../common/core/error/failures.dart';
import '../../core/constants/notifications_api_constants.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../data_sources/remote/notifications_remote_data_source.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl({
    required NotificationsRemoteDataSource remoteDataSource,
    required SharedPreferences preferences,
  }) : _remote = remoteDataSource,
       _preferences = preferences;

  final NotificationsRemoteDataSource _remote;
  final SharedPreferences _preferences;

  @override
  Future<Either<Failure, List<AppNotification>>> getNotifications() =>
      ErrorHandler.guard(_remote.getMyNotifications, tag: 'Notifications');

  @override
  DateTime? get seenAt {
    final value = _preferences.getString(NotificationsApiConstants.seenAtKey);
    return value == null ? null : DateTime.tryParse(value);
  }

  @override
  Future<Either<Failure, Unit>> markSeen(DateTime at) =>
      ErrorHandler.guard(() async {
        final previous = seenAt;
        if (previous != null && !at.isAfter(previous)) return unit;
        final ok = await _preferences.setString(
          NotificationsApiConstants.seenAtKey,
          at.toUtc().toIso8601String(),
        );
        if (!ok) throw const CacheException();
        return unit;
      }, tag: 'Notifications.seen');
}
