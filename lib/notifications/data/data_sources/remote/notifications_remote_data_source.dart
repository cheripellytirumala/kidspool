import '../../../../common/core/error/exceptions.dart';
import '../../../../common/core/network/api_client.dart';
import '../../../../common/core/utils/logger.dart';
import '../../../core/constants/notifications_api_constants.dart';
import '../../../domain/entities/app_notification.dart';
import '../../models/app_notification_model.dart';

/// Throws only `AppException` subtypes; never returns raw JSON.
abstract interface class NotificationsRemoteDataSource {
  /// Newest first. Empty when the RPC isn't deployed yet.
  Future<List<AppNotification>> getMyNotifications();
}

class NotificationsRemoteDataSourceImpl
    implements NotificationsRemoteDataSource {
  const NotificationsRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<AppNotification>> getMyNotifications() async {
    try {
      return await _apiClient.rpc(
        NotificationsApiConstants.getMyNotifications,
        parser: (json) {
          if (json is! List) throw const ParsingException();
          return AppNotificationModel.listFromJson(json);
        },
      );
    } on UnauthorizedException {
      rethrow;
    } on ServerException catch (e) {
      // Not on the server yet: nothing to show rather than an error.
      // PostgREST answers 404 / `PGRST202` for an RPC that isn't deployed.
      final missing =
          e.data['code'] == NotificationsApiConstants.functionNotFound ||
          e.code == NotificationsApiConstants.functionNotFound ||
          (e.statusCode == 404 && e.code == null);
      if (missing) {
        AppLogger.warning(
          'get_my_notifications is not deployed',
          tag: 'Notifications',
        );
        return const [];
      }
      throw ServerException(
        e.code == 'not_authenticated'
            ? 'Your session expired. Please sign in again.'
            : "Couldn't load your notifications. Pull to refresh.",
        e.statusCode,
        e.code,
        e.data,
      );
    }
  }
}
