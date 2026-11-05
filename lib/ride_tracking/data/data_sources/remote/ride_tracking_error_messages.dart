import '../../../../common/core/error/exceptions.dart';
import '../../../core/utils/ride_format.dart';

/// Friendly text for the ride-day RPC error codes (ported from the previous
/// app's `RideTrackingRemoteDataSource.messageFor`).
abstract final class RideTrackingErrorMessages {
  /// Codes meaning the ride isn't running any more: stop reporting GPS.
  static const Set<String> notActiveCodes = {
    'ride_not_in_progress',
    'ride_not_found',
  };

  static String? forCode(String? code, {String? details}) {
    switch (code) {
      case 'not_authenticated':
        return 'Your session expired. Please sign in again.';
      case 'ride_not_found':
        return 'We couldn’t find this ride.';
      case 'too_early_to_start':
        // details: "you can start from 2026-10-20 07:20" (ride's zone).
        final from = details == null
            ? null
            : DateTime.tryParse(details.split('from ').last.trim());
        return from == null
            ? 'You can start the ride from 30 minutes before pickup.'
            : 'You can start the ride from ${RideFormat.clock(from)}, '
                  '30 minutes before pickup.';
      case 'already_started':
        return 'This ride has already started.';
      case 'cannot_start':
        return 'This ride can’t be started any more.';
      case 'ride_not_started':
        return 'Start the ride before marking the pickup.';
      case 'already_picked_up':
        return 'The kids are already marked as picked up.';
      case 'ride_not_in_progress':
        return 'This ride isn’t in progress any more.';
      case 'not_picked_up':
        return 'Mark the kids as picked up first.';
      case 'ride_not_active':
        return 'This ride isn’t active, so SOS can’t be sent.';
      case 'ride_not_completed':
        return 'You can say thank you once the ride is completed.';
      case 'already_rated':
        return 'You already thanked them for this ride.';
      case 'ride_request_not_found':
        return 'We couldn’t find this ride.';
      case 'invalid_field':
        return 'Your location looks wrong. Please try again.';
      default:
        return null;
    }
  }

  /// Rewrites a [ServerException]'s message for ride codes; other
  /// exceptions are returned unchanged.
  static Object map(Object error, String fallback) {
    if (error is UnauthorizedException || error is! ServerException) {
      return error;
    }
    final details = error.data['details'];
    final message =
        forCode(error.code, details: details is String ? details : null) ??
        (error.code == null && (error.statusCode ?? 500) >= 500
            ? error.message
            : fallback);
    return ServerException(message, error.statusCode, error.code, error.data);
  }
}
