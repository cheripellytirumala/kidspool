import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/ask_ride/core/utils/ride_date_format.dart';
import 'package:kidspool/ask_ride/domain/entities/ride_time.dart';
import 'package:kidspool/ask_ride/presentation/widgets/ride_calendar.dart';
import 'package:kidspool/ask_ride/presentation/widgets/schedule_sheets.dart';

void main() {
  final today = DateTime(2026, 11, 26);

  Future<DateTime?> pump(WidgetTester tester, DateTime start) async {
    DateTime? moved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RideCalendar(
            start: start,
            firstDate: today,
            isSelected: (_) => false,
            onDayTap: (_) {},
            onWeekChanged: (w) => moved = w,
          ),
        ),
      ),
    );
    return moved;
  }

  testWidgets('one week from today: no past days, back is off', (tester) async {
    await pump(tester, today);
    expect(find.text('Nov 26 – Dec 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Today, Thursday, Nov 26'), findsOneWidget);
    expect(find.bySemanticsLabel('Wednesday, Nov 25'), findsNothing);
    expect(find.bySemanticsLabel('Wednesday, Dec 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Thursday, Dec 3'), findsNothing);
    final back = tester.widget<Semantics>(
      find.bySemanticsLabel('Previous week').first,
    );
    expect(back.properties.enabled, isFalse);
  });

  testWidgets('a start before today still shows today first', (tester) async {
    await pump(tester, DateTime(2026, 11, 1));
    expect(find.text('Nov 26 – Dec 2'), findsOneWidget);
  });

  test('weekOf lines weeks up with today', () {
    expect(RideCalendar.weekOf(today, today), today);
    expect(RideCalendar.weekOf(DateTime(2026, 12, 2), today), today);
    expect(
      RideCalendar.weekOf(DateTime(2026, 12, 3), today),
      DateTime(2026, 12, 3),
    );
    expect(RideCalendar.weekOf(DateTime(2026, 11, 1), today), today);
    expect(
      RideDateFormat.range(DateTime(2026, 12, 3), DateTime(2026, 12, 9)),
      'Dec 3 – 9',
    );
  });

  testWidgets('Which days? never holds more than 20 days', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WhichDaysSheet(maxDays: 20))),
    );
    // 6 weekday chips x 4 weeks = 24 days wanted.
    for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']) {
      await tester.tap(find.bySemanticsLabel(d));
      await tester.pump();
    }
    expect(find.textContaining('20 of 20 days picked'), findsOneWidget);
    expect(find.textContaining('up to 20 days'), findsOneWidget);
    // Removing a weekday frees room and clears the warning.
    await tester.tap(find.bySemanticsLabel('Mon'));
    await tester.pump();
    expect(find.textContaining('16 of 20 days picked'), findsOneWidget);
    expect(find.textContaining('up to 20 days'), findsNothing);
  });

  testWidgets('a weekday button skips today once it is too late', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    // A pick-up time that has already passed today (or is under 2 h away).
    final time = RideTime(now.hour, 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WhichDaysSheet(initialTime: time)),
      ),
    );
    await tester.tap(
      find.bySemanticsLabel(RideDateFormat.weekdayShort(now.weekday)),
    );
    await tester.pump();
    expect(find.textContaining('3 of 20 days picked'), findsOneWidget);
    expect(find.textContaining('2 hours ahead'), findsNothing);
  });
}
