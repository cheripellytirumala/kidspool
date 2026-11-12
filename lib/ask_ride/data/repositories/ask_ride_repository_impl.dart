import 'package:fpdart/fpdart.dart';

import '../../../add_kids/domain/repositories/kids_repository.dart';
import '../../../common/core/error/error_handler.dart';
import '../../../common/core/error/failures.dart';
import '../../../common/domain/entities/picked_address.dart';
import '../../domain/entities/ask_ride_kid.dart';
import '../../domain/entities/ride_request_result.dart';
import '../../domain/entities/saved_place.dart';
import '../../domain/repositories/ask_ride_repository.dart';
import '../data_sources/local/ask_ride_local_data_source.dart';
import '../data_sources/remote/ask_ride_remote_data_source.dart';

/// Wrap every method body in `ErrorHandler.guard` so exceptions become
/// failures before leaving the data layer.
///
/// Kids are read through the Kids feature's repository (`get_my_kids` +
/// signed photo URLs) so both features show the same data.
class AskRideRepositoryImpl implements AskRideRepository {
  const AskRideRepositoryImpl({
    required AskRideRemoteDataSource remoteDataSource,
    required AskRideLocalDataSource localDataSource,
    required KidsRepository kidsRepository,
  }) : _remote = remoteDataSource,
       _local = localDataSource,
       _kids = kidsRepository;

  final AskRideRemoteDataSource _remote;
  // ignore: unused_field
  final AskRideLocalDataSource _local;
  final KidsRepository _kids;

  @override
  Future<Either<Failure, List<AskRideKid>>> getKids() async {
    final result = await _kids.getKids();
    return result.map(
      (kids) => [
        for (final k in kids)
          AskRideKid(
            id: k.id,
            name: k.firstName,
            photo: k.photo,
            schoolId: k.schoolId,
            schoolName: k.schoolName,
            needsBooster: k.needsBooster,
          ),
      ],
    );
  }

  @override
  Future<Either<Failure, List<SavedPlace>>> getSavedPlaces() =>
      ErrorHandler.guard(_remote.getMyAddresses, tag: 'AskRide.addresses');

  @override
  Future<Either<Failure, RideRequestResult>> createRideRequest(
    CreateRideParams params,
  ) => ErrorHandler.guard(
    () => _remote.createRideRequest(params),
    tag: 'AskRide.create',
  );

  @override
  Future<Either<Failure, Unit>> setKidSchool(String kidId, String schoolId) =>
      _kids.assignSchool(kidIds: {kidId}, schoolId: schoolId);

  @override
  Future<Either<Failure, DropOffAddress>> getSchoolAddress(SavedPlace school) =>
      ErrorHandler.guard(
        () => _remote.getSchoolAddress(school.id, school.name),
        tag: 'AskRide.school',
      );

  @override
  Future<Either<Failure, List<SavedPlace>>> addSavedPlace(
    PickedAddress address, {
    required String label,
  }) {
    return ErrorHandler.guard(tag: 'AskRideRepository.addSavedPlace', () async {
      await _remote.addAddress(address, label: label);
      return _remote.getMyAddresses();
    });
  }
}
