import '../../../../common/core/network/api_client.dart';
import '../../../core/constants/ride_tracking_api_constants.dart';
import '../../../domain/entities/ride_alert.dart';
import '../../models/ride_alert_model.dart';

/// `get_my_notifications`, keeping only ride alerts.
/// Throws only `AppException` subtypes.
abstract interface class RideAlertsRemoteDataSource {
  Future<List<RideAlert>> getRideAlerts();
}

class RideAlertsRemoteDataSourceImpl implements RideAlertsRemoteDataSource {
  const RideAlertsRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<RideAlert>> getRideAlerts() => _apiClient.rpc(
    RideTrackingApiConstants.getMyNotifications,
    parser: RideAlertModel.listFromJson,
  );
}
