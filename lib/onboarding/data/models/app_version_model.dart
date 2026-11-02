import '../../../common/core/utils/json_parser.dart';

/// Wire format of the `check_app_version` RPC:
/// `{status: "ok"}` or
/// `{status: "force_update", minSupportedVersion, storeUrl, message}`.
class AppVersionModel {
  const AppVersionModel({
    this.status,
    this.minSupportedVersion,
    this.storeUrl,
    this.message,
  });

  final String? status;
  final String? minSupportedVersion;
  final String? storeUrl;
  final String? message;

  static const _status = 'status';
  static const _minSupportedVersion = 'minSupportedVersion';
  static const _storeUrl = 'storeUrl';
  static const _message = 'message';

  factory AppVersionModel.fromJson(Map<String, dynamic> json) {
    return AppVersionModel(
      status: json.readString(_status),
      minSupportedVersion: json.readString(_minSupportedVersion),
      storeUrl: json.readString(_storeUrl),
      message: json.readString(_message),
    );
  }

  Map<String, dynamic> toJson() => {
    _status: status,
    _minSupportedVersion: minSupportedVersion,
    _storeUrl: storeUrl,
    _message: message,
  };
}
