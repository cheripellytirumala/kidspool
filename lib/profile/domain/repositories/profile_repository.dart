import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/domain/entities/picked_address.dart';
import '../entities/profile_details.dart';
import '../entities/ride_mode.dart';
import '../entities/saved_address.dart';

/// Profile contract. Kids and `get_my_status` come from the shared
/// `KidsRepository` / `AccountRepository` instead.
abstract interface class ProfileRepository {
  /// `profiles` row of the signed-in user.
  Future<Either<Failure, ProfileDetails>> getDetails();

  /// Saved addresses, default first.
  Future<Either<Failure, List<SavedAddress>>> getAddresses();

  /// Saves [address] and returns the refreshed list.
  Future<Either<Failure, List<SavedAddress>>> addAddress(
    PickedAddress address, {
    required String label,
    required bool isDefault,
  });

  /// Returns the refreshed list.
  Future<Either<Failure, List<SavedAddress>>> setDefaultAddress(String id);

  /// Returns the refreshed list.
  Future<Either<Failure, List<SavedAddress>>> deleteAddress(String id);

  /// Ride mode picked on About you (stored on the device).
  RideMode getRideMode();

  Future<Either<Failure, RideMode>> setRideMode(RideMode mode);
}
