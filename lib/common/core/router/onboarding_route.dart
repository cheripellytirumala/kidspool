import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/my_status.dart';
import '../di/injection_container.dart';
import '../services/ride_mode_store.dart';
import 'app_routes.dart';

/// Where a signed-in user should land, based on `get_my_status`.
abstract final class OnboardingRoute {
  static String of(MyStatus status, {bool? riderOnly}) {
    if (!status.hasRole || !status.hasDefaultAddress) {
      return AppRoutes.aboutYou;
    }
    final kidsOrHome = status.kidsCount == 0
        ? AppRoutes.addChild
        : AppRoutes.home;
    return switch (status.onboardingStatus) {
      // Parents who only need rides skip the ID / license step.
      OnboardingStatus.notStarted =>
        (riderOnly ?? isRiderOnly()) ? kidsOrHome : AppRoutes.scanPhotoId,
      // Only a rejected ID stops the flow (retake photos). While the ID is
      // in review the parent keeps going.
      OnboardingStatus.rejected => AppRoutes.reviewPending,
      OnboardingStatus.pendingReview || OnboardingStatus.approved => kidsOrHome,
    };
  }

  /// "I need rides" was chosen on this device (no license needed).
  static bool isRiderOnly() =>
      sl.isRegistered<SharedPreferences>() &&
      RideModeStore.isRiderOnly(sl<SharedPreferences>());

  /// Can this parent use the app past sign-up? An ID sent (in review or
  /// approved), or — for parents who only need rides — none needed.
  static bool canUseApp(MyStatus status, {bool? riderOnly}) =>
      status.hasSubmittedId ||
      (status.onboardingStatus == OnboardingStatus.notStarted &&
          status.hasRole &&
          status.hasDefaultAddress &&
          (riderOnly ?? isRiderOnly()));
}
