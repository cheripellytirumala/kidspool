import '../../../common/core/utils/json_parser.dart';
import '../../domain/entities/ride_alert.dart';

/// Parses `get_my_notifications` rows into ride alerts.
abstract final class RideAlertModel {
  /// Ride rows only (other kinds are skipped), newest first.
  static List<RideAlert> listFromJson(Object? json) {
    if (json is! List) return const [];
    final alerts = <RideAlert>[];
    for (final row in json.whereType<Map>()) {
      final alert = fromJson(Map<String, dynamic>.from(row));
      if (alert != null) alerts.add(alert);
    }
    return alerts;
  }

  static RideAlert? fromJson(Map<String, dynamic> row) {
    final kind = RideAlertKind.fromValue(row.readString('kind'));
    final id = row.readString('id');
    final createdAt = DateTime.tryParse(row.readString('createdAt') ?? '');
    if (kind == null || id == null || createdAt == null) return null;
    final data = row['data'] is Map
        ? Map<String, dynamic>.from(row['data'] as Map)
        : const <String, dynamic>{};
    final requestId =
        data.readString('requestId') ??
        data.readString('request_id') ??
        data.readString('rideRequestId');
    final title = row.readString('title')?.trim();
    final body = row.readString('body')?.trim();
    return RideAlert(
      id: id,
      kind: kind,
      title: title == null || title.isEmpty
          ? (kind == RideAlertKind.started
                ? 'Ride started 🚗'
                : 'Arrived at school ✅')
          : title,
      body: body == null || body.isEmpty ? null : body,
      requestId: requestId,
      createdAt: createdAt.toLocal(),
    );
  }
}
