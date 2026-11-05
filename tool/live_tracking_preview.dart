// Debug-only preview of F22 Live tracking with fake ride data, to reproduce
// UI issues on a simulator without a real ride:
//   flutter run -t tool/live_tracking_preview.dart
import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import 'package:kidspool/common/core/di/injection_container.dart';
import 'package:kidspool/common/core/error/failures.dart';
import 'package:kidspool/common/core/router/app_router.dart';
import 'package:kidspool/common/core/router/app_routes.dart';
import 'package:kidspool/common/presentation/theme/app_theme.dart';
import 'package:kidspool/common/presentation/widgets/approval_gate.dart';
import 'package:kidspool/ride_tracking/domain/entities/ride_tracking.dart';
import 'package:kidspool/ride_tracking/domain/repositories/ride_tracking_repository.dart';

class _FakeTracking implements RideTrackingRepository {
  bool started = false;

  @override
  Future<Either<Failure, RideTracking>> getTracking(
    String requestId, {
    bool includePath = false,
  }) async => Right(
    RideTracking(
      requestId: requestId,
      status: started
          ? RideTrackingStatus.inProgress
          : RideTrackingStatus.confirmed,
      isDriver: true,
      pickupAt: DateTime.now().add(const Duration(minutes: 20)),
      startedAt: started ? DateTime.now() : null,
      pickup: const RideStop(label: 'Home', point: GeoPoint(37.7599, -122.4148)),
      // Far-away school (US home → Hyderabad) to reproduce long routes.
      school: const RideStop(
        label: "St Paul's School",
        point: GeoPoint(17.3851, 78.4866),
      ),
      kids: const [RideKid(id: 'k1', firstName: 'Emma')],
      parent: const RidePerson(name: 'Sarah Mitchell', initials: 'SM'),
    ),
  );

  @override
  Future<Either<Failure, Unit>> startRide(String requestId) async {
    started = true;
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> markPickedUp(String requestId) async =>
      const Right(unit);

  @override
  Future<Either<Failure, RideCompletion>> completeRide(String requestId) async =>
      const Right(RideCompletion());

  @override
  Future<Either<Failure, Unit>> triggerSos(String requestId) async =>
      const Right(unit);

  @override
  Future<Either<Failure, Unit>> sayThankYou(
    String requestId, {
    required int rating,
  }) async => const Right(unit);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  sl.allowReassignment = true;
  sl.registerSingleton<RideTrackingRepository>(_FakeTracking());
  // ignore: invalid_use_of_visible_for_testing_member
  ApprovalGate.debugAssumeApproved();
  runApp(
    MaterialApp(
      theme: AppTheme.light,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.liveTracking,
                arguments: const RideArgs('preview-ride'),
              ),
              child: const Text('Open live tracking'),
            ),
          ),
        ),
      ),
    ),
  );
}
