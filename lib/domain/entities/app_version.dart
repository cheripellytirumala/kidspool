import 'package:equatable/equatable.dart';

import 'distance_radius_filter.dart';

/// App configuration returned by the backend at launch.
///
/// Pure domain object: strongly typed, no JSON knowledge.
class AppVersion extends Equatable {
  const AppVersion({
    required this.paymentStatus,
    required this.productStatus,
    required this.paymentMessage,
    required this.productMessage,
    required this.apiBaseUrl,
    required this.latestVersion,
    required this.appLink,
    required this.deploymentStatus,
    required this.userDetailsFlag,
    required this.searchRadius,
    required this.distanceRadiusFilters,
    required this.isForcePaymentPage,
    required this.status,
  });

  final int paymentStatus;
  final int productStatus;
  final String paymentMessage;
  final String productMessage;
  final String apiBaseUrl;

  /// Latest version published on the store (e.g. `1.9.0`).
  final String latestVersion;
  final String appLink;

  /// Free-form string; the backend sends both `"1"` and `"1.0.39"`.
  final String deploymentStatus;
  final String? userDetailsFlag;
  final int searchRadius;
  final List<DistanceRadiusFilter> distanceRadiusFilters;
  final bool isForcePaymentPage;
  final int status;

  @override
  List<Object?> get props => [
    paymentStatus,
    productStatus,
    paymentMessage,
    productMessage,
    apiBaseUrl,
    latestVersion,
    appLink,
    deploymentStatus,
    userDetailsFlag,
    searchRadius,
    distanceRadiusFilters,
    isForcePaymentPage,
    status,
  ];
}
