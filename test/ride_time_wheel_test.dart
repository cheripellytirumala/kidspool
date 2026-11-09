import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/ask_ride/domain/entities/ride_time.dart';
import 'package:kidspool/ask_ride/presentation/widgets/ride_time_field.dart';

void main() {
  testWidgets('Pick up at opens a time wheel, not a text box', (tester) async {
    RideTime? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => RideTimeField(
              label: 'Pick up at',
              value: picked ?? const RideTime(8, 0),
              onChanged: (t) => setState(() => picked = t),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsNothing);
    expect(find.text('8:00 AM'), findsOneWidget);

    await tester.tap(find.byType(RideTimeField));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(picked, const RideTime(8, 0));
    expect(find.byType(CupertinoDatePicker), findsNothing);
  });

  testWidgets('the wheel starts on a 5-minute step', (tester) async {
    RideTime? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked = await showRideTimeWheel(
                context,
                title: 'Pick up at',
                initial: const RideTime(15, 33),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(picked, const RideTime(15, 30));
  });
}
