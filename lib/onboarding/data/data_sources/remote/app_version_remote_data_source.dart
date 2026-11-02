import '../../../../common/core/error/exceptions.dart';
import '../../../../common/core/network/api_client.dart';
import '../../../core/constants/onboarding_api_constants.dart';
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
    return _apiClient.rpc<AppVersionModel>(
      OnboardingApiConstants.checkAppVersion,
      params: {'platform': params.platform, 'appVersion': params.appVersion},
      // Public RPC: callable before sign-in.
      skipAuth: true,
      parser: (json) {
        if (json is! Map) {
          throw const ParsingException('Invalid app version response.');
        }
        return AppVersionModel.fromJson(Map<String, dynamic>.from(json));
      },
    );
  }
}
