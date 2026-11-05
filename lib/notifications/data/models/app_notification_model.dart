import '../../../common/core/utils/json_parser.dart';
import '../../domain/entities/app_notification.dart';

/// Parses `get_my_notifications` rows.
abstract final class AppNotificationModel {
  /// Newest first; rows without an id, title or time are skipped.
  static List<AppNotification> listFromJson(Object? json) {
    if (json is! List) return const [];
    final list = <AppNotification>[
      for (final row in json.whereType<Map>())
        ?fromJson(Map<String, dynamic>.from(row)),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  static AppNotification? fromJson(Map<String, dynamic> row) {
    final id = row.readString('id');
    final title = row.readString('title')?.trim();
    final createdAt = DateTime.tryParse(row.readString('createdAt') ?? '');
    if (id == null || title == null || title.isEmpty || createdAt == null) {
      return null;
    }
    final data = row['data'] is Map
        ? Map<String, dynamic>.from(row['data'] as Map)
        : const <String, dynamic>{};
    String? text(String? v) =>
        (v == null || v.trim().isEmpty) ? null : v.trim();
    return AppNotification(
      id: id,
      kind: NotificationKind.fromValue(row.readString('kind')),
      title: title,
      body: text(row.readString('body')),
      createdAt: createdAt.toLocal(),
      requestId: text(
        row.readString('requestId') ?? data.readString('requestId'),
      ),
      iAmDriver: row.readBool('iAmDriver') ?? false,
      otherName: text(row.readString('otherName')),
      otherInitials: text(row.readString('otherInitials')),
    );
  }
}
