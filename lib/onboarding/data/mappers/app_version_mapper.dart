import '../../domain/entities/app_version.dart';
import '../models/app_version_model.dart';

/// Model → Entity mapping. The only place wire defaults are decided.
extension AppVersionModelMapper on AppVersionModel {
  AppVersion toEntity() {
    return AppVersion(
      isUpdateRequired: status == 'force_update',
      minSupportedVersion: minSupportedVersion ?? '',
      storeUrl: storeUrl ?? '',
      message:
          message ?? 'A new version is required to continue. Please update.',
    );
  }
}
