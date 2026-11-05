import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/ride_alert.dart';
import '../repositories/ride_alerts_repository.dart';

/// Ride notifications for the in-app banner (`get_my_notifications`).
class GetRideAlerts implements UseCase<List<RideAlert>, NoParams> {
  const GetRideAlerts(this._repository);

  final RideAlertsRepository _repository;

  /// False before sign-in: callers skip the request.
  bool get canFetch => _repository.isSignedIn;

  @override
  Future<Either<Failure, List<RideAlert>>> call(NoParams params) =>
      _repository.getRideAlerts();
}
