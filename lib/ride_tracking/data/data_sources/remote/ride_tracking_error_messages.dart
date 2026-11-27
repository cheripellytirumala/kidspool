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
        return 'The members are already marked as picked up.';
      case 'ride_not_in_progress':
        return 'This ride isn’t in progress any more.';
      case 'not_picked_up':
        return 'Mark the members as picked up first.';
      case 'ride_not_active':
        return 'This ride isn’t active, so SOS can’t be sent.';
      case 'ride_request_not_found':
        return 'We couldn’t find this ride.';
      case 'pin_required':
        return 'Ask the member for their 4-digit pick-up PIN.';
      case 'pin_locked':
        return 'Too many wrong PINs. Wait 10 minutes, or call the member.';
      case 'wrong_pin':
        return wrongPin(null);
      case 'cannot_cancel':
        return 'This ride can’t be cancelled any more.';
      case 'invalid_field':
        return 'Your location looks wrong. Please try again.';
      default:
        return null;
    }
  }

  static String wrongPin(int? attemptsLeft) => switch (attemptsLeft) {
    null => 'That PIN isn’t right. Check it with the member.',
    0 => 'That PIN isn’t right. Too many tries — wait 10 minutes.',
    1 => 'That PIN isn’t right. 1 try left.',
    final n => 'That PIN isn’t right. $n tries left.',
  };

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
