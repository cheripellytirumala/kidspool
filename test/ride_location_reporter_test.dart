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
  testWidgets('sends every 10 s, re-sending the last fix when standing still', (
    tester,
  ) async {
    final gps = _Gps();
    final remote = _Remote();
    final reporter = RideLocationReporter(location: gps, tracking: remote)
      ..start('r1');

    gps.controller.add(const RideFix(latitude: 11.0, longitude: 76.9));
    await tester.pump();
    expect(remote.sent, hasLength(1)); // first fix goes out at once

    // Car stands still for 30 s: one update every 10 s anyway.
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 10));
    expect(remote.sent, hasLength(4));
    expect(remote.sent.every((f) => f.latitude == 11.0), isTrue);

    reporter.stop();
    await tester.pump(const Duration(seconds: 30));
    expect(remote.sent, hasLength(4));
    await gps.controller.close();
  });
}
