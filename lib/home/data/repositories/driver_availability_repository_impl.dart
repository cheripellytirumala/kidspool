import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/error_handler.dart';
import '../../../common/core/error/failures.dart';
import '../../../common/core/network/api_client.dart';
import '../../core/constants/home_api_constants.dart';
import '../../domain/repositories/driver_availability_repository.dart';

class DriverAvailabilityRepositoryImpl implements DriverAvailabilityRepository {
  const DriverAvailabilityRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Either<Failure, bool>> setAvailable(bool available) =>
      ErrorHandler.guard(
        tag: 'Home.setDriverAvailable',
        () => _api.rpc(
          HomeApiConstants.setDriverAvailable,
          params: {'available': available},
          parser: (json) => json is Map ? json['available'] == true : available,
        ),
      );
}
