import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/ask_ride/domain/entities/ride_lead_time.dart';
import 'package:kidspool/ask_ride/domain/entities/ride_time.dart';

void main() {
  final now = DateTime(2026, 11, 12, 9, 10);
  final today = DateTime(2026, 11, 12);
  final tomorrow = DateTime(2026, 11, 13);

  test('no lead time: any pick-up from now on is fine', () {
    expect(RideLeadTime.minimum, Duration.zero);
    // A few minutes from now, and right now.
    expect(
      RideLeadTime.isTooSoon(today, const RideTime(9, 15), now: now),
      isFalse,
    );
    expect(
      RideLeadTime.isTooSoon(today, const RideTime(9, 10), now: now),
      isFalse,
    );
    expect(
      RideLeadTime.isTooSoon(tomorrow, const RideTime(0, 5), now: now),
      isFalse,
    );
  });

  test('a pick-up time that has passed is blocked', () {
    expect(
      RideLeadTime.isTooSoon(today, const RideTime(8, 0), now: now),
      isTrue,
    );
    expect(
      RideLeadTime.tooSoonMessage([today], const RideTime(9, 0), now: now),
      'That time has already passed. Today, pick a time after 9:10 AM.',
    );
    expect(
      RideLeadTime.tooSoonMessage([today], const RideTime(9, 30), now: now),
      isNull,
    );
  });

  test('custom days: a passed time today blocks', () {
    expect(
      RideLeadTime.tooSoonMessage(
        [today, tomorrow],
        const RideTime(9, 0),
        now: now,
      ),
      isNotNull,
    );
    expect(
      RideLeadTime.tooSoonMessage(
        [today, tomorrow],
        const RideTime(9, 30),
        now: now,
      ),
      isNull,
    );
  });
}
