import '../../common/core/error/exceptions.dart';
import '../../common/core/network/api_client.dart';
import '../core/safety_api_constants.dart';
import '../domain/safety_entities.dart';

/// Report / block RPCs and the delete-account Edge Function.
/// Throws only `AppException` subtypes, with messages fit to show.
class SafetyRemoteDataSource {
  const SafetyRemoteDataSource(this._api);

  final ApiClient _api;

  Future<void> report({
    required String userId,
    required ReportReason reason,
    String? details,
    ReportContext? context,
    String? contextId,
    String? messageId,
    bool alsoBlock = false,
  }) => _guard(
    () => _api.rpc(
      SafetyApiConstants.reportUser,
      params: {
        'reported': userId,
        'reason': reason.code,
        'details': ?details,
        'context': ?context?.code,
        'context_id': ?contextId,
        'message_id': ?messageId,
        'also_block': alsoBlock,
      },
      parser: (_) {},
    ),
  );

  Future<void> block(String userId) => _guard(
    () => _api.rpc(
      SafetyApiConstants.blockUser,
      params: {'target': userId},
      parser: (_) {},
    ),
  );

  Future<void> unblock(String userId) => _guard(
    () => _api.rpc(
      SafetyApiConstants.unblockUser,
      params: {'target': userId},
      parser: (_) {},
    ),
  );

  Future<List<BlockedUser>> blocks() => _guard(
    () => _api.rpc(
      SafetyApiConstants.getMyBlocks,
      parser: (data) => [
        for (final item in (data as List<dynamic>? ?? const []))
          if (item is Map<String, dynamic>) BlockedUser.fromJson(item),
      ],
    ),
  );

  Future<void> deleteAccount() => _guard(
    () => _api.invokeFunction(
      SafetyApiConstants.deleteAccount,
      data: const <String, dynamic>{},
      parser: (_) {},
    ),
  );

  /// True for "this RPC / function isn't deployed yet".
  static bool isMissing(ServerException e) =>
      e.code == SafetyApiConstants.functionNotFound ||
      e.data['code'] == SafetyApiConstants.functionNotFound ||
      (e.statusCode == 404 && e.code == null) ||
      e.data['code'] == 'NOT_FOUND';

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on UnauthorizedException {
      rethrow;
    } on ServerException catch (e) {
      if (isMissing(e)) {
        throw ServerException(
          'This isn’t available yet. Please email support.',
          e.statusCode,
          SafetyApiConstants.functionNotFound,
          e.data,
        );
      }
      final code = (e.data['error'] ?? e.data['message'] ?? e.code)?.toString();
      final message = switch (code) {
        'ride_in_progress' =>
          'Finish or cancel your ride in progress before deleting your '
              'account.',
        'too_many_reports' => 'You’ve sent a lot of reports. Try again later.',
        'invalid_user' || 'user_not_found' => 'We couldn’t find this person.',
        _ => e.message,
      };
      throw ServerException(message, e.statusCode, e.code, e.data);
    }
  }
}
