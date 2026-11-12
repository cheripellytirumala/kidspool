import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/common/core/router/app_routes.dart';
import 'package:kidspool/common/core/router/onboarding_route.dart';
import 'package:kidspool/common/domain/entities/my_status.dart';

MyStatus _status(
  OnboardingStatus onboarding, {
  int kids = 0,
  bool address = true,
  String? role = 'parent',
}) => MyStatus(
  role: role,
  firstName: 'Vivek',
  lastName: 'L',
  onboardingStatus: onboarding,
  rejectionReason: null,
  kidsCount: kids,
  hasDefaultAddress: address,
);

void main() {
  group('no ID sent yet', () {
    final status = _status(OnboardingStatus.notStarted);

    test('parents who offer rides scan their license', () {
      expect(
        OnboardingRoute.of(status, riderOnly: false),
        AppRoutes.scanPhotoId,
      );
      expect(OnboardingRoute.canUseApp(status, riderOnly: false), isFalse);
    });

    test('parents who only need rides go to Add a child, then Home', () {
      expect(OnboardingRoute.of(status, riderOnly: true), AppRoutes.addChild);
      expect(
        OnboardingRoute.of(
          _status(OnboardingStatus.notStarted, kids: 2),
          riderOnly: true,
        ),
        AppRoutes.home,
      );
      expect(OnboardingRoute.canUseApp(status, riderOnly: true), isTrue);
    });
  });

  test('About you comes first for everyone', () {
    final noAddress = _status(OnboardingStatus.notStarted, address: false);
    expect(OnboardingRoute.of(noAddress, riderOnly: true), AppRoutes.aboutYou);
    expect(OnboardingRoute.canUseApp(noAddress, riderOnly: true), isFalse);
  });

  test('a rejected ID still stops riders and drivers', () {
    final rejected = _status(OnboardingStatus.rejected);
    expect(
      OnboardingRoute.of(rejected, riderOnly: true),
      AppRoutes.reviewPending,
    );
    expect(OnboardingRoute.canUseApp(rejected, riderOnly: true), isFalse);
  });

  test('an ID in review or approved carries on as before', () {
    for (final s in [
      OnboardingStatus.pendingReview,
      OnboardingStatus.approved,
    ]) {
      expect(
        OnboardingRoute.of(_status(s), riderOnly: false),
        AppRoutes.addChild,
      );
      expect(OnboardingRoute.canUseApp(_status(s), riderOnly: false), isTrue);
    }
  });
}
