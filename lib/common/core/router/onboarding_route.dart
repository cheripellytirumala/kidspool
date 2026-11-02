import '../../domain/entities/my_status.dart';
import 'app_routes.dart';

/// Where a signed-in user should land, based on `get_my_status`.
abstract final class OnboardingRoute {
  static String of(MyStatus status) {
    if (!status.hasRole || !status.hasDefaultAddress) {
      return AppRoutes.aboutYou;
    }
    return switch (status.onboardingStatus) {
      OnboardingStatus.notStarted => AppRoutes.scanPhotoId,
      // Only a rejected ID stops the flow (retake photos). While the ID is
      // in review the parent keeps going.
      OnboardingStatus.rejected => AppRoutes.reviewPending,
      OnboardingStatus.pendingReview || OnboardingStatus.approved =>
        status.kidsCount == 0 ? AppRoutes.addChild : AppRoutes.home,
    };
  }
}
