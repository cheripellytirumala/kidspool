import '../../core/utils/json_parser.dart';
import 'distance_radius_filter_model.dart';

/// Wire format of `getAppVersion`. Every field is nullable and read with
/// type-tolerant helpers; defaults are applied in the mapper.
class AppVersionModel {
  const AppVersionModel({
    this.paymentStatus,
    this.productStatus,
    this.paymentMessage,
    this.productMessage,
    this.apiBaseUrl,
    this.version,
    this.appLink,
    this.deploymentStatus,
    this.userDetailsFlag,
    this.searchRadius,
    this.distanceRadiusFilters = const [],
    this.isForcePaymentPage,
    this.status,
  });

  final int? paymentStatus;
  final int? productStatus;
  final String? paymentMessage;
  final String? productMessage;
  final String? apiBaseUrl;
  final String? version;
  final String? appLink;
  final String? deploymentStatus;
  final String? userDetailsFlag;
  final int? searchRadius;
  final List<DistanceRadiusFilterModel> distanceRadiusFilters;
  final bool? isForcePaymentPage;
  final int? status;

  static const _paymentStatus = 'payment_status';
  static const _productStatus = 'product_status';
  static const _paymentMessage = 'payment_message';
  static const _productMessage = 'product_message';
  static const _apiBaseUrl = 'api_base_url';
  static const _version = 'version';
  static const _appLink = 'App_Link';
  static const _deploymentStatus = 'deployment_status';
  static const _userDetailsFlag = 'user_details_flag';
  static const _searchRadius = 'search_radius';
  static const _distanceRadiusFilters = 'distance_radius_filters';
  static const _isForcePaymentPage = 'is_force_payment_page';
  static const _status = 'status';

  factory AppVersionModel.fromJson(Map<String, dynamic> json) {
    return AppVersionModel(
      paymentStatus: json.readInt(_paymentStatus),
      productStatus: json.readInt(_productStatus),
      paymentMessage: json.readString(_paymentMessage),
      productMessage: json.readString(_productMessage),
      apiBaseUrl: json.readString(_apiBaseUrl),
      version: json.readString(_version),
      appLink: json.readString(_appLink),
      deploymentStatus: json.readString(_deploymentStatus),
      userDetailsFlag: json.readString(_userDetailsFlag),
      searchRadius: json.readInt(_searchRadius),
      distanceRadiusFilters: json.readList(
        _distanceRadiusFilters,
        DistanceRadiusFilterModel.fromJson,
      ),
      isForcePaymentPage: json.readBool(_isForcePaymentPage),
      status: json.readInt(_status),
    );
  }

  /// Mirrors the server format so cached JSON round-trips through [fromJson].
  Map<String, dynamic> toJson() => {
    _paymentStatus: paymentStatus,
    _productStatus: productStatus,
    _paymentMessage: paymentMessage,
    _productMessage: productMessage,
    _apiBaseUrl: apiBaseUrl,
    _version: version,
    _appLink: appLink,
    _deploymentStatus: deploymentStatus,
    _userDetailsFlag: userDetailsFlag,
    _searchRadius: searchRadius?.toString(),
    _distanceRadiusFilters: distanceRadiusFilters
        .map((e) => e.toJson())
        .toList(),
    _isForcePaymentPage: isForcePaymentPage == null
        ? null
        : (isForcePaymentPage! ? '1' : '0'),
    _status: status,
  };
}
