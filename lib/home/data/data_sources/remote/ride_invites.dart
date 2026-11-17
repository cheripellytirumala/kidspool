import '../../../../common/core/error/error_handler.dart';
import '../../../../common/core/network/api_client.dart';

/// `invite_to_ride_request(requestIds, parentIds)`: gives the families the
/// parent picked on Families near you the ride request, so the Hi can go
/// into each ride chat and they can tap "I can help".
/// Returns an error message to show, or null.
Future<String?> inviteToRideRequest(
  ApiClient api,
  List<String> requestIds,
  List<String> parentIds,
) async {
  if (requestIds.isEmpty || parentIds.isEmpty) return null;
  final result = await ErrorHandler.guard(
    tag: 'Home.inviteToRide',
    () => api.rpc(
      'invite_to_ride_request',
      params: {'requestIds': requestIds, 'parentIds': parentIds},
      parser: (_) {},
    ),
  );
  return result.match((f) => f.message, (_) => null);
}
