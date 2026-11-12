import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/ask_ride/domain/entities/ride_lead_time.dart';
import 'package:kidspool/ask_ride/domain/entities/ride_time.dart';

void main() {
  final now = DateTime(2026, 11, 12, 9, 10);
  final today = DateTime(2026, 11, 12);
  final tomorrow = DateTime(2026, 11, 13);

  test('pick-up less than 2 hours away is too soon', () {
    expect(
      RideLeadTime.isTooSoon(today, const RideTime(11, 0), now: now),
      isTrue,
    );
    expect(
      RideLeadTime.isTooSoon(today, const RideTime(11, 10), now: now),
      isFalse,
    );
    expect(
      RideLeadTime.isTooSoon(today, const RideTime(8, 0), now: now),
      isTrue,
    );
    expect(
      RideLeadTime.isTooSoon(tomorrow, const RideTime(8, 0), now: now),
      isFalse,
    );
  });

  test('message names the earliest time today', () {
    expect(
      RideLeadTime.tooSoonMessage([today], const RideTime(10, 0), now: now),
      'Ask at least 2 hours ahead. Today, pick a time after 11:10 AM.',
    );
    expect(
      RideLeadTime.tooSoonMessage([tomorrow], const RideTime(10, 0), now: now),
      isNull,
    );
  });

  test('custom days: any day too soon blocks', () {
    expect(
      RideLeadTime.tooSoonMessage(
        [today, tomorrow],
        const RideTime(9, 30),
        now: now,
      ),
      isNotNull,
    );
  });

  test('late evening: earliest is tomorrow', () {
    final late = DateTime(2026, 11, 12, 23, 0);
    expect(
      RideLeadTime.tooSoonMessage([tomorrow], const RideTime(0, 30), now: late),
      'Ask at least 2 hours ahead. Pick a later day or time.',
    );
  });
}
