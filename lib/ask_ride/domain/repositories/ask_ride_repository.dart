import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/domain/entities/picked_address.dart';
import '../entities/ask_ride_kid.dart';
import '../entities/ride_request_result.dart';
import '../entities/saved_place.dart';

/// AskRide contract. Methods return `Future<Either<Failure, T>>`.
abstract interface class AskRideRepository {
  Future<Either<Failure, List<AskRideKid>>> getKids();

  /// Saved addresses (pick-up points), default first.
  Future<Either<Failure, List<SavedPlace>>> getSavedPlaces();

  /// Saves an address picked on the map and returns the updated list.
  Future<Either<Failure, List<SavedPlace>>> addSavedPlace(
    PickedAddress address, {
    required String label,
  });

  Future<Either<Failure, RideRequestResult>> createRideRequest(
    CreateRideParams params,
  );

  /// Sets [schoolId] as [kidId]'s school (a kid added without one).
  Future<Either<Failure, Unit>> setKidSchool(String kidId, String schoolId);

  /// Where the school is, for a ride that picks up there (ride home).
  Future<Either<Failure, DropOffAddress>> getSchoolAddress(SavedPlace school);
}
