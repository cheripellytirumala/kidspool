import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../entities/auth_requests.dart';

/// Auth contract. Methods return `Future<Either<Failure, T>>`.
abstract interface class AuthRepository {
  /// Sends a 6-digit code to [phone] (E.164, e.g. `+14155550142`).
  Future<Either<Failure, OtpRequest>> requestOtp(String phone);

  /// Verifies the code and stores the Supabase session on the device.
  Future<Either<Failure, Unit>> verifyOtp({
    required String phone,
    required String code,
  });

  /// Sets the profile role to `parent` (no-op when a role is already set).
  Future<Either<Failure, Unit>> setParentRole();

  Future<Either<Failure, Unit>> addHomeAddress(HomeAddress address);

  /// Uploads the selfie + ID photos; the profile moves to `pending_review`.
  Future<Either<Failure, Unit>> submitIdentity(IdentitySubmission submission);
}
