import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/error_handler.dart';
import '../../../common/core/error/failures.dart';
import '../../../common/domain/entities/picked_address.dart';
import '../../domain/entities/profile_details.dart';
import '../../domain/entities/ride_mode.dart';
import '../../domain/entities/saved_address.dart';
import '../../domain/repositories/profile_repository.dart';
import '../data_sources/local/profile_local_data_source.dart';
import '../data_sources/remote/profile_remote_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl({
    required ProfileRemoteDataSource remoteDataSource,
    required ProfileLocalDataSource localDataSource,
  }) : _remote = remoteDataSource,
       _local = localDataSource;

  final ProfileRemoteDataSource _remote;
  final ProfileLocalDataSource _local;

  @override
  Future<Either<Failure, ProfileDetails>> getDetails() =>
      ErrorHandler.guard(tag: 'Profile.details', _remote.getDetails);

  @override
  Future<Either<Failure, List<SavedAddress>>> getAddresses() =>
      ErrorHandler.guard(tag: 'Profile.addresses', _remote.getMyAddresses);

  @override
  Future<Either<Failure, List<SavedAddress>>> addAddress(
    PickedAddress address, {
    required String label,
    required bool isDefault,
  }) => ErrorHandler.guard(tag: 'Profile.addAddress', () async {
    await _remote.addAddress(address, label: label, isDefault: isDefault);
    return _remote.getMyAddresses();
  });

  @override
  Future<Either<Failure, List<SavedAddress>>> setDefaultAddress(String id) =>
      ErrorHandler.guard(tag: 'Profile.setDefaultAddress', () async {
        await _remote.setDefaultAddress(id);
        return _remote.getMyAddresses();
      });

  @override
  Future<Either<Failure, List<SavedAddress>>> deleteAddress(String id) =>
      ErrorHandler.guard(tag: 'Profile.deleteAddress', () async {
        await _remote.deleteAddress(id);
        return _remote.getMyAddresses();
      });

  @override
  RideMode getRideMode() => _local.getRideMode();

  @override
  Future<Either<Failure, RideMode>> setRideMode(RideMode mode) =>
      ErrorHandler.guard(tag: 'Profile.setRideMode', () async {
        await _local.saveRideMode(mode);
        return mode;
      });
}
