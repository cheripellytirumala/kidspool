import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../../../common/domain/repositories/places_repository.dart';
import '../entities/geo_point.dart';
import '../repositories/kids_repository.dart';

/// Where to center "near home" searches: the parent's default saved
/// address, else the device's current position. `null` when neither is
/// available (search then runs without a bias).
class GetHomeLocation implements UseCase<GeoPoint?, NoParams> {
  const GetHomeLocation(this._kids, this._places);

  final KidsRepository _kids;
  final PlacesRepository _places;

  @override
  Future<Either<Failure, GeoPoint?>> call(NoParams params) async {
    final home = (await _kids.homeLocation()).toNullable();
    if (home != null) return Right(home);
    final here = (await _places.currentLocation()).toNullable();
    return Right(here == null ? null : GeoPoint(here.latitude, here.longitude));
  }
}
