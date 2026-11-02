import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/ask_ride_kid.dart';
import '../entities/saved_place.dart';
import '../repositories/ask_ride_repository.dart';

/// What the parent can choose from on G1: their kids and saved places.
class RideOptions {
  const RideOptions({required this.kids, required this.places});

  final List<AskRideKid> kids;
  final List<SavedPlace> places;
}

class GetRideOptions implements UseCase<RideOptions, NoParams> {
  const GetRideOptions(this._repository);

  final AskRideRepository _repository;

  /// Pick-up points are the saved addresses; drop-offs are the kids'
  /// schools (the only destination `create_ride_request` supports).
  @override
  Future<Either<Failure, RideOptions>> call(NoParams params) async {
    final (kids, places) = await (
      _repository.getKids(),
      _repository.getSavedPlaces(),
    ).wait;
    return kids.flatMap(
      (k) => places.map((addresses) {
        final schools = <String, SavedPlace>{};
        for (final kid in k) {
          final id = kid.schoolId;
          if (id == null || schools.containsKey(id)) continue;
          schools[id] = SavedPlace(
            id: id,
            name: kid.schoolName ?? 'School',
            address: kid.schoolName ?? '',
            kind: PlaceKind.school,
          );
        }
        return RideOptions(kids: k, places: [...addresses, ...schools.values]);
      }),
    );
  }
}
