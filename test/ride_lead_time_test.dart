import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/ask_ride/domain/entities/ride_lead_time.dart';
import 'package:kidspool/ask_ride/domain/entities/ride_time.dart';
import 'package:kidspool/ask_ride/presentation/widgets/ride_calendar.dart';

void main() {
  final now = DateTime(2026, 11, 12, 9, 10);
  final today = DateTime(2026, 11, 12);
  final tomorrow = DateTime(2026, 11, 13);

  test('no 2-hour notice: any time from now on is fine', () {
    expect(
      RideLeadTime.isTooSoon(today, const RideTime(9, 30), now: now),
      isFalse,
    );
    expect(
      RideLeadTime.isTooSoon(today, const RideTime(9, 10), now: now),
      isFalse,
    );
    expect(
      RideLeadTime.isTooSoon(tomorrow, const RideTime(8, 0), now: now),
      isFalse,
    );
  });

  test('a time that has passed is still blocked', () {
    expect(
      RideLeadTime.isTooSoon(today, const RideTime(8, 0), now: now),
      isTrue,
    );
    expect(
      RideLeadTime.tooSoonMessage([today], const RideTime(8, 0), now: now),
      'That time has passed. Today, pick a time after 9:10 AM.',
    );
    expect(
      RideLeadTime.tooSoonMessage(
        [today, tomorrow],
        const RideTime(9, 0),
        now: now,
      ),
      isNotNull,
    );
    expect(
      RideLeadTime.tooSoonMessage([tomorrow], const RideTime(8, 0), now: now),
      isNull,
    );
  });

  test('calendar shows the current week and the next one', () {
    // Tue Nov 24, 2026 → Sun Nov 22 … Sat Dec 5.
    final days = RideCalendar.shownDays(DateTime(2026, 11, 24));
    expect(days, hasLength(14));
    expect(days.first, DateTime(2026, 11, 22));
    expect(days.last, DateTime(2026, 12, 5));
    expect(days.first.weekday, DateTime.sunday);
  });
}
