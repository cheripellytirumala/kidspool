import 'package:flutter/material.dart';

import '../../../ask_ride/presentation/screens/ask_ride_details_screen.dart';
import '../../../ask_ride/presentation/screens/message_sent_screen.dart';
import '../../../auth/presentation/screens/about_you_screen.dart';
import '../../../auth/presentation/screens/id_verified_screen.dart';
import '../../../auth/presentation/screens/otp_screen.dart';
import '../../../auth/presentation/screens/phone_number_screen.dart';
import '../../../auth/presentation/screens/review_pending_screen.dart';
import '../../../auth/presentation/screens/scan_photo_id_screen.dart';
import '../../../home/presentation/screens/families_near_you_screen.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../add_kids/presentation/screens/add_child_screen.dart';
import '../../../add_kids/presentation/screens/all_set_screen.dart';
import '../../../add_kids/presentation/screens/child_places_screen.dart';
import '../../../add_kids/presentation/screens/find_school_screen.dart';
import '../../../add_kids/presentation/screens/where_kids_go_screen.dart';
import '../../../add_kids/presentation/screens/who_goes_when_screen.dart';
import '../../../add_kids/presentation/screens/your_kids_screen.dart';
import '../../../onboarding/presentation/screens/splash_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../ride_tracking/presentation/screens/live_tracking_screen.dart';
import '../../../ride_tracking/presentation/screens/ride_completed_screen.dart';
import '../../presentation/widgets/approval_gate.dart';
import 'app_routes.dart';

/// Central route table. Screens navigate with
/// `Navigator.pushNamed(context, AppRoutes.x)`.
abstract final class AppRouter {
  static final Map<String, WidgetBuilder> _routes = {
    AppRoutes.splash: (_) => const SplashScreen(),
    AppRoutes.phoneNumber: (_) => const PhoneNumberScreen(),
    AppRoutes.otp: (_) => const OtpScreen(),
    AppRoutes.aboutYou: (_) => const AboutYouScreen(),
    AppRoutes.scanPhotoId: (_) => const ScanPhotoIdScreen(),
    AppRoutes.idVerified: (_) => const IdVerifiedScreen(),
    AppRoutes.reviewPending: (_) => const ReviewPendingScreen(),
    AppRoutes.addChild: (_) => const AddChildScreen(),
    AppRoutes.yourKids: (_) => const YourKidsScreen(),
    AppRoutes.whereKidsGo: (_) => const WhereKidsGoScreen(),
    AppRoutes.findSchool: (_) => const FindSchoolScreen(),
    AppRoutes.whoGoesWhen: (_) => const WhoGoesWhenScreen(),
    AppRoutes.childPlaces: (_) => const ChildPlacesScreen(),
    AppRoutes.allSet: (_) => const AllSetScreen(),
    AppRoutes.home: (_) => const HomeScreen(),
    AppRoutes.familiesNearYou: (_) => const FamiliesNearYouScreen(),
    AppRoutes.askRide: (_) => const AskRideDetailsScreen(),
    AppRoutes.messageSent: (_) => const MessageSentScreen(),
    AppRoutes.profile: (_) => const ProfileScreen(),
    // Ride-day screens read [RideArgs] from the route settings.
    AppRoutes.liveTracking: (_) => const LiveTrackingScreen(),
    AppRoutes.rideCompleted: (_) => const RideCompletedScreen(),
  };

  /// Screens that need an approved ID (see [ApprovalGate]). Sign-up,
  /// review and Profile (to log out or retake the ID) stay open.
  static const Set<String> _needsApproval = {
    AppRoutes.addChild,
    AppRoutes.yourKids,
    AppRoutes.whereKidsGo,
    AppRoutes.findSchool,
    AppRoutes.whoGoesWhen,
    AppRoutes.childPlaces,
    AppRoutes.allSet,
    AppRoutes.home,
    AppRoutes.familiesNearYou,
    AppRoutes.askRide,
    AppRoutes.messageSent,
    AppRoutes.liveTracking,
    AppRoutes.rideCompleted,
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final builder = _routes[settings.name];
    if (builder == null) return null;
    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: _needsApproval.contains(settings.name)
          ? (context) => ApprovalGate(child: builder(context))
          : builder,
    );
  }
}
