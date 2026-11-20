import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/ride_tracking/data/data_sources/local/ride_location_data_source.dart';
import 'package:kidspool/ride_tracking/data/data_sources/remote/ride_tracking_remote_data_source.dart';
import 'package:kidspool/ride_tracking/data/models/ride_fix.dart';
import 'package:kidspool/ride_tracking/data/services/ride_location_reporter.dart';

class _Gps implements RideLocationDataSource {
  final controller = StreamController<RideFix>.broadcast();

  @override
  Future<RideFix?> currentFix() async => null;

  @override
  Stream<RideFix> fixes() => controller.stream;
}

class _Remote implements RideTrackingRemoteDataSource {
  final sent = <RideFix>[];

  @override
  Future<double?> updateLocation(String requestId, RideFix at) async {
    sent.add(at);
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'sends every interval, re-sending the last fix when standing still',
    (tester) async {
      final gps = _Gps();
      final remote = _Remote();
      final reporter = RideLocationReporter(location: gps, tracking: remote)
        ..start('r1');

      gps.controller.add(const RideFix(latitude: 11.0, longitude: 76.9));
      await tester.pump();
      expect(remote.sent, hasLength(1)); // first fix goes out at once

      // Car stands still: one update every interval anyway.
      const tick = RideLocationReporter.interval;
      await tester.pump(tick);
      await tester.pump(tick);
      await tester.pump(tick);
      expect(remote.sent, hasLength(4));
      expect(remote.sent.every((f) => f.latitude == 11.0), isTrue);

      reporter.stop();
      await tester.pump(const Duration(seconds: 30));
      expect(remote.sent, hasLength(4));
      await gps.controller.close();
    },
  );

  testWidgets('skips a poor GPS fix right after a good one', (tester) async {
    final gps = _Gps();
    final remote = _Remote();
    final reporter = RideLocationReporter(location: gps, tracking: remote)
      ..start('r1');

    gps.controller.add(
      const RideFix(latitude: 11.0, longitude: 76.9, accuracy: 8),
    );
    await tester.pump();
    // 300 m off, 200 m accuracy: ignored, the good fix is re-sent instead.
    gps.controller.add(
      const RideFix(latitude: 11.003, longitude: 76.9, accuracy: 200),
    );
    await tester.pump(RideLocationReporter.interval);
    expect(remote.sent.map((f) => f.latitude), everyElement(11.0));

    reporter.stop();
    await gps.controller.close();
  });
}
