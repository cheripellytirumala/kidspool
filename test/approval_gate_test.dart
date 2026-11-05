import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:kidspool/common/core/config/environment.dart';
import 'package:kidspool/common/core/di/injection_container.dart';
import 'package:kidspool/common/core/error/failures.dart';
import 'package:kidspool/common/core/router/app_router.dart';
import 'package:kidspool/common/core/router/app_routes.dart';
import 'package:kidspool/common/domain/entities/my_status.dart';
import 'package:kidspool/common/domain/repositories/account_repository.dart';
import 'package:kidspool/common/presentation/theme/app_theme.dart';
import 'package:kidspool/common/presentation/widgets/approval_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAccount implements AccountRepository {
  OnboardingStatus status = OnboardingStatus.pendingReview;

  @override
  bool get isSignedIn => true;

  @override
  Future<Either<Failure, MyStatus>> getMyStatus() async => Right(
    MyStatus(
      role: 'parent',
      firstName: 'Sarah',
      lastName: 'Mitchell',
      onboardingStatus: status,
      rejectionReason: null,
      kidsCount: 0,
      hasDefaultAddress: true,
    ),
  );

  @override
  Future<void> signOut() async {}
}

/// Kids/home screens open once the license was sent (in review or
/// approved); unfinished sign-up or a rejected ID sends the user back.
void main() {
  final account = _FakeAccount();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initDependencies(config: EnvConfig.of(Environment.production));
    sl.allowReassignment = true;
    sl.registerSingleton<AccountRepository>(account);
  });

  setUp(ApprovalGate.reset);

  Future<String?> openAndSettle(WidgetTester tester, String route) async {
    String? current;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        onGenerateRoute: (s) {
          current = s.name;
          return AppRouter.onGenerateRoute(s);
        },
        onGenerateInitialRoutes: (_) => [
          AppRouter.onGenerateRoute(RouteSettings(name: route))!,
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    final shown = current;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    return shown;
  }

  for (final route in [AppRoutes.addChild, AppRoutes.home, AppRoutes.askRide]) {
    testWidgets('$route opens while the ID is in review', (tester) async {
      account.status = OnboardingStatus.pendingReview;
      // No redirect: the only route generated is the initial one.
      expect(await openAndSettle(tester, route), isNull);
    });
  }

  testWidgets('rejected ID goes to retake photos', (tester) async {
    account.status = OnboardingStatus.rejected;
    expect(
      await openAndSettle(tester, AppRoutes.addChild),
      AppRoutes.reviewPending,
    );
  });

  testWidgets('ID not sent yet goes to scan', (tester) async {
    account.status = OnboardingStatus.notStarted;
    expect(
      await openAndSettle(tester, AppRoutes.addChild),
      AppRoutes.scanPhotoId,
    );
  });

  testWidgets('approved parent can open Add a child', (tester) async {
    account.status = OnboardingStatus.approved;
    // No redirect: the only route generated is the initial one.
    expect(await openAndSettle(tester, AppRoutes.addChild), isNull);
  });
}
