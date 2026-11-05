import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/error_handler.dart';
import '../../../common/core/error/failures.dart';
import '../../domain/entities/ride_tracking.dart';
import '../../domain/repositories/ride_tracking_repository.dart';
import '../data_sources/local/ride_location_data_source.dart';
import '../data_sources/remote/ride_tracking_remote_data_source.dart';

class RideTrackingRepositoryImpl implements RideTrackingRepository {
  const RideTrackingRepositoryImpl({
    required RideTrackingRemoteDataSource remoteDataSource,
    required RideLocationDataSource locationDataSource,
  }) : _remote = remoteDataSource,
       _location = locationDataSource;

  final RideTrackingRemoteDataSource _remote;
  final RideLocationDataSource _location;

  static const _tag = 'RideTrackingRepository';

  @override
  Future<Either<Failure, RideTracking>> getTracking(
    String requestId, {
    bool includePath = false,
  }) => ErrorHandler.guard(
    () => _remote.getTracking(requestId, includePath: includePath),
    tag: _tag,
  );

  // Ride actions send where the phone is when it knows (optional on the
  // backend), so the parent's map and the drop-off check stay accurate.

  @override
  Future<Either<Failure, Unit>> startRide(String requestId) =>
      ErrorHandler.guard(() async {
        await _remote.startRide(requestId, await _location.currentFix());
        return unit;
      }, tag: _tag);

  @override
  Future<Either<Failure, Unit>> markPickedUp(String requestId) =>
      ErrorHandler.guard(() async {
        await _remote.markPickedUp(requestId, await _location.currentFix());
        return unit;
      }, tag: _tag);

  @override
  Future<Either<Failure, RideCompletion>> completeRide(String requestId) =>
      ErrorHandler.guard(
        () async =>
            _remote.completeRide(requestId, await _location.currentFix()),
        tag: _tag,
      );

  @override
  Future<Either<Failure, Unit>> triggerSos(String requestId) =>
      ErrorHandler.guard(() async {
        await _remote.triggerSos(requestId, await _location.currentFix());
        return unit;
      }, tag: _tag);

  @override
  Future<Either<Failure, Unit>> sayThankYou(
    String requestId, {
    required int rating,
  }) => ErrorHandler.guard(() async {
    await _remote.rateRide(requestId, rating: rating, thankYou: true);
    return unit;
  }, tag: _tag);
}
