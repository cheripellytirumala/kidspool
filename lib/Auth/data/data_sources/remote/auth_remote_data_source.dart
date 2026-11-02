import 'package:dio/dio.dart';

import '../../../../common/core/error/exceptions.dart';
import '../../../../common/core/network/api_client.dart';
import '../../../../common/core/network/auth_token_provider.dart';
import '../../../../common/core/utils/json_parser.dart';
import '../../../core/constants/auth_api_constants.dart';
import '../../../domain/entities/auth_requests.dart';

/// Throws only `AppException` subtypes; never returns raw JSON.
abstract interface class AuthRemoteDataSource {
  Future<OtpRequest> requestOtp(String phone);

  /// Returns the session created by `verify-otp`.
  Future<AuthSession> verifyOtp({required String phone, required String code});

  Future<void> setMyRole(String role);

  Future<void> addAddress(HomeAddress address);

  Future<void> submitIdentity(IdentitySubmission submission);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<OtpRequest> requestOtp(String phone) {
    return _apiClient.invokeFunction(
      AuthApiConstants.requestOtp,
      data: {'phone': phone},
      skipAuth: true,
      parser: (json) {
        final map = _asMap(json);
        return OtpRequest(
          expiresIn: map.readInt('expiresIn') ?? 300,
          resendAfter: map.readInt('resendAfter') ?? 30,
          demoCode: map.readString('otp'),
        );
      },
    );
  }

  @override
  Future<AuthSession> verifyOtp({required String phone, required String code}) {
    return _apiClient.invokeFunction(
      AuthApiConstants.verifyOtp,
      data: {'phone': phone, 'otp': code},
      skipAuth: true,
      parser: (json) {
        final map = _asMap(json);
        final session = map['session'];
        final user = map['user'];
        if (session is! Map) throw const ParsingException();
        final s = Map<String, dynamic>.from(session);
        final access = s.readString('accessToken');
        final refresh = s.readString('refreshToken');
        if (access == null || refresh == null) throw const ParsingException();
        final expiresIn = s.readInt('expiresIn') ?? 3600;
        return AuthSession(
          accessToken: access,
          refreshToken: refresh,
          expiresAt:
              s.readInt('expiresAt') ??
              DateTime.now().millisecondsSinceEpoch ~/ 1000 + expiresIn,
          userId: user is Map ? user['id']?.toString() : null,
        );
      },
    );
  }

  @override
  Future<void> setMyRole(String role) {
    return _apiClient.rpc<void>(
      AuthApiConstants.setMyRole,
      params: {'role': role},
      parser: (_) {},
    );
  }

  @override
  Future<void> addAddress(HomeAddress address) {
    return _apiClient.rpc<void>(
      AuthApiConstants.addAddress,
      params: {
        'addressLine1': address.street.trim(),
        'addressLine2': address.apt.trim().isEmpty ? null : address.apt.trim(),
        'city': address.city.trim(),
        'state': address.stateCode.trim(),
        'zip': address.zip.trim(),
        'latitude': address.latitude,
        'longitude': address.longitude,
        'label': 'Home',
        'isDefault': address.isDefault,
      },
      parser: (_) {},
    );
  }

  @override
  Future<void> submitIdentity(IdentitySubmission submission) async {
    final form = FormData.fromMap({
      'firstName': submission.firstName.trim(),
      'lastName': submission.lastName.trim(),
      'idType': submission.idType,
      'selfie': await MultipartFile.fromFile(submission.selfiePath),
      'idFront': await MultipartFile.fromFile(submission.idFrontPath),
      if (submission.idBackPath != null)
        'idBack': await MultipartFile.fromFile(submission.idBackPath!),
    });
    await _apiClient.invokeFunction<void>(
      AuthApiConstants.submitIdentityVerification,
      data: form,
      parser: (_) {},
    );
  }

  static Map<String, dynamic> _asMap(dynamic json) {
    if (json is! Map) throw const ParsingException();
    return Map<String, dynamic>.from(json);
  }
}
