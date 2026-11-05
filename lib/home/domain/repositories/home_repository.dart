import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../entities/family.dart';
import '../entities/ride_activity.dart';
import '../entities/upcoming_ride.dart';

/// Home contract. Methods return `Future<Either<Failure, T>>`.
abstract interface class HomeRepository {
  /// Open, confirmed and in-progress rides, soonest first.
  Future<Either<Failure, List<UpcomingRide>>> getUpcomingRides();

  /// Confirmed and in-progress rides the user gives, soonest first.
  Future<Either<Failure, List<UpcomingRide>>> getUpcomingDrives();

  /// Driver and route group of the ride request [requestId].
  Future<Either<Failure, RideActivity>> getRideActivity(String requestId);

  /// True when a notification arrived after the user last opened the bell.
  Future<Either<Failure, bool>> hasUnseenNotifications();

  /// Marks every current notification as seen.
  Future<Either<Failure, Unit>> markNotificationsSeen();

  /// Families whose kids share a school with the user's kids, nearest
  /// first (`get_families_near_me`). Fails with code
  /// `HomeApiConstants.familiesNearMeMissing` when the RPC isn't on the
  /// server; once seen, that failure is returned without another request.
  Future<Either<Failure, FamiliesNearMe>> getFamiliesNearMe({
    String? schoolId,
    double? radiusMiles,
  });
}
