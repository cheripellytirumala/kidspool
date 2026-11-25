import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';

/// Whether a Ride Partner takes new ride requests right now.
abstract interface class DriverAvailabilityRepository {
  /// Turns the driver on or off (also refreshes "still on"). Returns the
  /// server's value.
  Future<Either<Failure, bool>> setAvailable(bool available);
}
