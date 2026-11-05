import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../entities/ride_alert.dart';

/// Ride notifications (S19 / S20), newest first.
abstract interface class RideAlertsRepository {
  /// True when someone is signed in (no point asking the backend otherwise).
  bool get isSignedIn;

  Future<Either<Failure, List<RideAlert>>> getRideAlerts();
}
