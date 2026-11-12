import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../../../common/core/router/app_routes.dart';
import '../../domain/entities/ride_alert.dart';
import '../../../messages/presentation/screens/ride_request_detail_screen.dart'
    show RideRequestArgs;

/// What a tapped S19 / S20 notification carries: which card it was and which
/// ride to open.
///
/// The same shape travels in a local notification's `payload` (JSON string)
/// and in a push's `data` map (`{kind, requestId}`, sent by the
/// `send-ride-push` Edge Function).
class RideAlertPayload extends Equatable {
  const RideAlertPayload({required this.kind, required this.requestId});

  /// From an alert the app already has; null when it names no ride.
  static RideAlertPayload? fromAlert(RideAlert alert) {
    final id = alert.requestId;
    if (id == null || id.isEmpty) return null;
    return RideAlertPayload(kind: alert.kind, requestId: id);
  }

  /// From a push's `data`: `{kind: 'ride_started' | 'ride_arrived',
  /// requestId}`. Null for pushes that aren't about a ride in progress.
  static RideAlertPayload? fromData(Map<String, dynamic> data) {
    final kind = RideAlertKind.fromValue(data['kind']?.toString());
    final id = (data['requestId'] ?? data['request_id'])?.toString();
    if (kind == null || id == null || id.isEmpty) return null;
    return RideAlertPayload(kind: kind, requestId: id);
  }

  /// From a local notification's payload string; null when it's missing or
  /// isn't one of ours.
  static RideAlertPayload? decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final json = jsonDecode(payload);
      if (json is! Map) return null;
      return fromData(Map<String, dynamic>.from(json));
    } on FormatException {
      return null;
    }
  }

  final RideAlertKind kind;

  /// `ride_requests.id`.
  final String requestId;

  /// Backend kind, as in `get_my_notifications().kind`.
  String get kindValue => switch (kind) {
    RideAlertKind.accepted => 'ride_confirmed',
    RideAlertKind.started => 'ride_started',
    RideAlertKind.arrived => 'ride_arrived',
  };

  /// JSON payload for a local notification.
  String encode() => jsonEncode({'kind': kindValue, 'requestId': requestId});

  /// Screen to open: the ride's details once accepted, live tracking for
  /// S19, the ride summary for S20.
  String get route => switch (kind) {
    RideAlertKind.accepted => AppRoutes.rideRequestDetail,
    RideAlertKind.started => AppRoutes.liveTracking,
    RideAlertKind.arrived => AppRoutes.rideCompleted,
  };

  Object get arguments => switch (kind) {
    RideAlertKind.accepted => RideRequestArgs(
      requestId: requestId,
      isMine: true,
    ),
    _ => RideArgs(requestId),
  };

  @override
  List<Object?> get props => [kind, requestId];
}

/// System notification ids shared with the `send-ride-push` Edge Function,
/// so a push and the local notification for the same event replace each
/// other instead of showing twice.
abstract final class RideAlertNotificationId {
  /// Stable 31-bit FNV-1a hash of the alert id (`ride_started:<requestId>`).
  /// iOS: the local notification's identifier (and the push's
  /// `apns-collapse-id`). The Edge Function computes the same value.
  static int of(String alertId) {
    var hash = 0x811c9dc5;
    for (final unit in alertId.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}
