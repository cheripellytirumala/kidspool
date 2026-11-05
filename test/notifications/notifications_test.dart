import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/notifications/core/utils/notification_time.dart';
import 'package:kidspool/notifications/data/models/app_notification_model.dart';
import 'package:kidspool/notifications/domain/entities/app_notification.dart';

void main() {
  group('AppNotificationModel', () {
    test('parses rows newest first and skips invalid ones', () {
      final list = AppNotificationModel.listFromJson([
        {
          'id': 'ride_confirmed:a',
          'kind': 'ride_confirmed',
          'title': 'Jen will drive Emma',
          'body': 'Thu, Oct 23 · 7:45 AM · to Lincoln',
          'createdAt': '2026-11-04T10:00:00Z',
          'requestId': 'a',
          'iAmDriver': false,
          'otherInitials': 'JP',
        },
        {
          'id': 'ride_started:b',
          'kind': 'ride_started',
          'title': 'Ride started 🚗',
          'createdAt': '2026-11-05T10:00:00Z',
          'data': {'requestId': 'b'},
        },
        {'id': 'x', 'kind': 'ride_started', 'title': '', 'createdAt': 'bad'},
        {
          'id': 'y',
          'kind': 'brand_new',
          'title': 'Hi',
          'body': ' ',
          'createdAt': '2026-11-01T10:00:00Z',
        },
      ]);
      expect(list.map((n) => n.id), [
        'ride_started:b',
        'ride_confirmed:a',
        'y',
      ]);
      expect(list.first.requestId, 'b');
      expect(list.first.kind, NotificationKind.rideStarted);
      expect(list[1].otherInitials, 'JP');
      expect(list.last.kind, NotificationKind.other);
      expect(list.last.body, isNull);
    });

    test('non-list JSON gives an empty list', () {
      expect(AppNotificationModel.listFromJson({'a': 1}), isEmpty);
    });
  });

  group('NotificationTime', () {
    final now = DateTime(2026, 11, 5, 12); // Thursday
    test('labels like F25b', () {
      expect(NotificationTime.label(now, now: now), 'now');
      expect(
        NotificationTime.label(
          now.subtract(const Duration(minutes: 2)),
          now: now,
        ),
        '2m',
      );
      expect(
        NotificationTime.label(
          now.subtract(const Duration(hours: 3)),
          now: now,
        ),
        '3h',
      );
      expect(NotificationTime.label(DateTime(2026, 11, 4, 9), now: now), 'Wed');
      expect(
        NotificationTime.label(DateTime(2026, 10, 12, 9), now: now),
        'Oct 12',
      );
      expect(
        NotificationTime.label(DateTime(2025, 10, 12, 9), now: now),
        'Oct 12, 2025',
      );
    });
    test('spoken form', () {
      expect(
        NotificationTime.spoken(
          now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        '1 minute ago',
      );
      expect(
        NotificationTime.spoken(
          now.subtract(const Duration(hours: 2)),
          now: now,
        ),
        '2 hours ago',
      );
    });
  });
}
