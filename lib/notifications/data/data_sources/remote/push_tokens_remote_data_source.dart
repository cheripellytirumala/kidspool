import '../../../../common/core/error/exceptions.dart';
import '../../../../common/core/network/api_client.dart';
import '../../../../common/core/utils/logger.dart';
import '../../../core/constants/notifications_api_constants.dart';

/// `register_push_token` / `unregister_push_token`.
/// Throws only `AppException` subtypes.
abstract interface class PushTokensRemoteDataSource {
  /// False when the RPC isn't deployed yet (nothing was stored).
  Future<bool> register({required String token, required String platform});

  /// False when the RPC isn't deployed yet.
  Future<bool> unregister(String token);
}

class PushTokensRemoteDataSourceImpl implements PushTokensRemoteDataSource {
  const PushTokensRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<bool> register({required String token, required String platform}) =>
      _call(NotificationsApiConstants.registerPushToken, {
        'token': token,
        'platform': platform,
      });

  @override
  Future<bool> unregister(String token) =>
      _call(NotificationsApiConstants.unregisterPushToken, {'token': token});

  Future<bool> _call(String name, Map<String, dynamic> params) async {
    try {
      // Both return void: PostgREST answers 204 / an empty body.
      return await _apiClient.rpc(name, params: params, parser: (_) => true);
    } on UnauthorizedException {
      rethrow;
    } on ServerException catch (e) {
      // PostgREST answers 404 / `PGRST202` before the SQL is applied.
      final missing =
          e.data['code'] == NotificationsApiConstants.functionNotFound ||
          e.code == NotificationsApiConstants.functionNotFound ||
          (e.statusCode == 404 && e.code == null);
      if (!missing) rethrow;
      AppLogger.warning('$name is not deployed', tag: 'Push');
      return false;
    }
  }
}
