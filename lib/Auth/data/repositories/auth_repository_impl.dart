import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/error_handler.dart';
import '../../../common/core/error/exceptions.dart';
import '../../../common/core/error/failures.dart';
import '../../../common/core/network/auth_token_provider.dart';
import '../../core/constants/auth_api_constants.dart';
import '../../domain/entities/auth_requests.dart';
import '../../domain/repositories/auth_repository.dart';
import '../data_sources/local/auth_local_data_source.dart';
import '../data_sources/remote/auth_remote_data_source.dart';

/// Wrap every method body in `ErrorHandler.guard` so exceptions become
/// failures before leaving the data layer.
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
    required AuthTokenProvider tokenProvider,
  }) : _remote = remoteDataSource,
       _local = localDataSource,
       _tokens = tokenProvider;

  final AuthRemoteDataSource _remote;
  // ignore: unused_field
  final AuthLocalDataSource _local;
  final AuthTokenProvider _tokens;

  @override
  Future<Either<Failure, OtpRequest>> requestOtp(String phone) =>
      ErrorHandler.guard(() => _remote.requestOtp(phone), tag: 'Auth.otp');

  @override
  Future<Either<Failure, Unit>> verifyOtp({
    required String phone,
    required String code,
  }) => ErrorHandler.guard(tag: 'Auth.verify', () async {
    final session = await _remote.verifyOtp(phone: phone, code: code);
    await _tokens.saveSession(session);
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> setParentRole() =>
      ErrorHandler.guard(tag: 'Auth.role', () async {
        try {
          await _remote.setMyRole(AuthApiConstants.roleParent);
        } on ServerException catch (e) {
          // Returning users already have a role: nothing to do.
          if (e.code != 'role_already_set') rethrow;
        }
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> addHomeAddress(HomeAddress address) =>
      ErrorHandler.guard(tag: 'Auth.address', () async {
        await _remote.addAddress(address);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> submitIdentity(IdentitySubmission submission) =>
      ErrorHandler.guard(tag: 'Auth.identity', () async {
        await _remote.submitIdentity(submission);
        return unit;
      });
}
