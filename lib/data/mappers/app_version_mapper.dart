import '../../domain/entities/app_version.dart';
import '../../domain/entities/distance_radius_filter.dart';
import '../models/app_version_model.dart';
import '../models/distance_radius_filter_model.dart';

/// Model → Entity mapping. The only place wire defaults are decided.
extension AppVersionModelMapper on AppVersionModel {
  AppVersion toEntity() {
    return AppVersion(
      paymentStatus: paymentStatus ?? 0,
      productStatus: productStatus ?? 0,
      paymentMessage: paymentMessage ?? '',
      productMessage: productMessage ?? '',
      apiBaseUrl: apiBaseUrl ?? '',
      latestVersion: version ?? '',
      appLink: appLink ?? '',
      deploymentStatus: deploymentStatus ?? '',
      userDetailsFlag: userDetailsFlag,
      searchRadius: searchRadius ?? 0,
      distanceRadiusFilters: distanceRadiusFilters
          .where((f) => f.radius != null)
          .map((f) => f.toEntity())
          .toList(growable: false),
      isForcePaymentPage: isForcePaymentPage ?? false,
      status: status ?? 0,
    );
  }
}

extension DistanceRadiusFilterModelMapper on DistanceRadiusFilterModel {
  DistanceRadiusFilter toEntity() => DistanceRadiusFilter(radius: radius ?? 0);
}
