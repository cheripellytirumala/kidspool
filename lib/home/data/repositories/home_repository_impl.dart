import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/error_handler.dart';
import '../../../common/core/error/failures.dart';
import '../../domain/entities/ride_activity.dart';
import '../../domain/entities/upcoming_ride.dart';
import '../../domain/repositories/home_repository.dart';
import '../data_sources/local/home_local_data_source.dart';
import '../data_sources/remote/home_remote_data_source.dart';

/// Wrap every method body in `ErrorHandler.guard` so exceptions become
/// failures before leaving the data layer.
class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl({
    required HomeRemoteDataSource remoteDataSource,
    required HomeLocalDataSource localDataSource,
  }) : _remote = remoteDataSource,
       _local = localDataSource;

  final HomeRemoteDataSource _remote;
  final HomeLocalDataSource _local;

  /// Newest notification time from the last [hasUnseenNotifications].
  DateTime? _latestNotificationAt;

  @override
  Future<Either<Failure, List<UpcomingRide>>> getUpcomingRides() =>
      ErrorHandler.guard(_remote.getUpcomingRides, tag: 'Home.rides');

  @override
  Future<Either<Failure, List<UpcomingRide>>> getUpcomingDrives() =>
      ErrorHandler.guard(_remote.getUpcomingDrives, tag: 'Home.drives');

  @override
  Future<Either<Failure, RideActivity>> getRideActivity(String requestId) =>
      ErrorHandler.guard(
        () => _remote.getRideActivity(requestId),
        tag: 'Home.activity',
      );

  @override
  Future<Either<Failure, bool>> hasUnseenNotifications() =>
      ErrorHandler.guard(() async {
        final latest = await _remote.getLatestNotificationAt();
        _latestNotificationAt = latest;
        if (latest == null) return false;
        final seen = _local.getNotificationsSeenAt();
        return seen == null || latest.isAfter(seen);
      }, tag: 'Home.notifications');

  @override
  Future<Either<Failure, Unit>> markNotificationsSeen() =>
      ErrorHandler.guard(() async {
        final latest = _latestNotificationAt;
        if (latest != null) await _local.setNotificationsSeenAt(latest);
        return unit;
      }, tag: 'Home.notificationsSeen');
}
