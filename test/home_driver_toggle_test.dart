import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:kidspool/common/core/error/failures.dart';
import 'package:kidspool/common/domain/entities/my_status.dart';
import 'package:kidspool/common/domain/repositories/account_repository.dart';
import 'package:kidspool/home/domain/entities/family.dart';
import 'package:kidspool/home/domain/entities/upcoming_ride.dart';
import 'package:kidspool/home/domain/repositories/home_repository.dart';
import 'package:kidspool/home/domain/usecases/get_families_near_me.dart';
import 'package:kidspool/home/presentation/providers/home_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _offline = ServerFailure('offline');

class _Home implements HomeRepository {
  @override
  Future<Either<Failure, List<UpcomingRide>>> getUpcomingRides() async =>
      const Right([]);

  @override
  Future<Either<Failure, List<UpcomingRide>>> getUpcomingDrives() async =>
      const Right([]);

  @override
  Future<Either<Failure, bool>> hasUnseenNotifications() async =>
      const Right(false);

  @override
  Future<Either<Failure, FamiliesNearMe>> getFamiliesNearMe({
    String? schoolId,
    double? radiusMiles,
  }) async => const Left(_offline);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Account implements AccountRepository {
  _Account(this.license);
  final OnboardingStatus license;

  @override
  Future<Either<Failure, MyStatus>> getMyStatus() async => Right(
    MyStatus(
      role: 'parent',
      firstName: 'Jordan',
      lastName: 'K',
      onboardingStatus: OnboardingStatus.approved,
      rejectionReason: null,
      kidsCount: 1,
      hasDefaultAddress: true,
      licenseStatus: license,
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<HomeProvider> _home({
  required String? rideRole,
  required OnboardingStatus license,
}) async {
  SharedPreferences.setMockInitialValues({'ride_role': ?rideRole});
  final repo = _Home();
  final p = HomeProvider(
    repository: repo,
    account: _Account(license),
    preferences: await SharedPreferences.getInstance(),
    getFamiliesNearMe: GetFamiliesNearMe(repo),
  );
  await p.load();
  return p;
}

void main() {
  test('Available switch: approved driver who gives rides only', () async {
    expect(
      (await _home(
        rideRole: 'both',
        license: OnboardingStatus.approved,
      )).isDriver,
      isTrue,
    );
  });

  test('no switch for a parent without an approved licence', () async {
    for (final license in [
      OnboardingStatus.notStarted,
      OnboardingStatus.pendingReview,
      OnboardingStatus.rejected,
    ]) {
      expect(
        (await _home(rideRole: 'both', license: license)).isDriver,
        isFalse,
        reason: '$license',
      );
    }
  });

  test('no switch for a parent who only needs rides', () async {
    expect(
      (await _home(
        rideRole: 'seeker',
        license: OnboardingStatus.approved,
      )).isDriver,
      isFalse,
    );
  });
}
