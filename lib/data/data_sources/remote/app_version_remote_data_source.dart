import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/json_parser.dart';
import '../../../domain/usecases/get_app_version.dart';
import '../../models/app_version_model.dart';

abstract interface class AppVersionRemoteDataSource {
  /// Throws [NetworkException], [ServerException] or [ParsingException].
  Future<AppVersionModel> getAppVersion(GetAppVersionParams params);
}

class AppVersionRemoteDataSourceImpl implements AppVersionRemoteDataSource {
  const AppVersionRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<AppVersionModel> getAppVersion(GetAppVersionParams params) {
    return _apiClient.post<AppVersionModel>(
      ApiConstants.getAppVersion,
      queryParameters: {
        ApiConstants.qRoleId: params.roleId,
        ApiConstants.qDevice: params.device,
        ApiConstants.qVersionNumber: params.versionNumber,
      },
      // Public endpoint: no bearer token.
      options: Options(extra: {ApiConstants.extraSkipAuth: true}),
      parser: _parse,
    );
  }

  AppVersionModel _parse(dynamic json) {
    if (json is! Map) {
      throw const ParsingException('Invalid app version response.');
    }
    final map = Map<String, dynamic>.from(json);

    // API-level failure: HTTP 200 but `status` != 1.
    final status = map.readInt(ApiConstants.kStatus);
    if (status != ApiConstants.statusSuccess) {
      throw ServerException(
        map.readString(ApiConstants.kMessage) ?? 'Unable to fetch app version.',
      );
    }

    return AppVersionModel.fromJson(map);
  }
}
