/// Backend names for report / block / delete account.
/// SQL: docs/backend/2026-11-16_reports_and_blocks.sql.
/// Edge Function: supabase/functions/delete-account.
abstract final class SafetyApiConstants {
  static const String reportUser = 'report_user';
  static const String blockUser = 'block_user';
  static const String unblockUser = 'unblock_user';
  static const String getMyBlocks = 'get_my_blocks';
  static const String deleteAccount = 'delete-account';

  /// PostgREST: function not deployed yet.
  static const String functionNotFound = 'PGRST202';

  /// Blocked ids kept on the device, per signed-in user.
  static String blocksCacheKey(String userId) => 'blocked_users_$userId';
}
