import '../../../add_kids/presentation/providers/kids_provider.dart';
import '../../../common/presentation/state/live_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/usecase/usecase.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/widgets/app_badge.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_bottom_nav.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../../messages/presentation/screens/ride_request_detail_screen.dart';
import '../../../notifications/core/services/ride_notifications.dart';
import '../../../profile/domain/usecases/sign_out.dart';
import '../../../profile/presentation/widgets/profile_sheets.dart';
import '../../core/constants/home_assets.dart';
import '../../core/constants/home_text_styles.dart';
import '../../domain/entities/upcoming_ride.dart' show RideStatus;
import '../../domain/entities/home_role.dart';
import '../providers/home_provider.dart';
import '../widgets/ask_ride_action_card.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/family_preview_card.dart';
import '../widgets/home_hero_card.dart';
import '../widgets/home_ride_map_card.dart';
import '../widgets/ride_group_card.dart';

/// Home dashboard.
///
/// * H3 · Home · Both — when a ride is booked for the user's kids
///   (`get_my_ride_requests`, confirmed / in progress) or the user drives one
///   (`get_my_drives`): the map card with "Track", Ask for a ride, the ride
///   group and families.
/// * H1e / H3e — otherwise: the hero card with the empty state for
///   [HomeProvider.role] (or the open requests' summary).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = sl<HomeProvider>();
    // Refresh name + upcoming rides whenever Home is (re)built as a route.
    Future.microtask(provider.load);
    // Signed in and on Home: ask for notification permission (once), register
    // for push, open a ride from a tapped notification.
    Future.microtask(sl<RideNotifications>().onHomeShown);
    // Brings this phone's kids' activities in sync with the server (once
    // per session), so families can be matched by activity.
    Future.microtask(sl<KidsProvider>().load);
    return ChangeNotifierProvider<HomeProvider>.value(
      value: provider,
      child: LiveRefreshListener(
        onRefresh: () => provider.load(silent: true),
        child: const _HomeView(),
      ),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  void _openFamilies(BuildContext context) =>
      Navigator.pushNamed(context, AppRoutes.familiesNearYou);

  void _askRide(BuildContext context, HomeProvider provider) =>
      Navigator.pushNamed(
        context,
        AppRoutes.askRide,
      ).then((_) => provider.load());

  /// A ride the driver has started opens live tracking; before that (still
  /// asking, or booked but not started) it opens its request (A7a).
  void _openNextRide(BuildContext context, HomeProvider provider) {
    final ride = provider.nextRide;
    if (ride == null) return;
    final route = ride.status == RideStatus.inProgress
        ? Navigator.pushNamed(
            context,
            AppRoutes.liveTracking,
            arguments: RideArgs(ride.id),
          )
        : Navigator.pushNamed(
            context,
            AppRoutes.rideRequestDetail,
            arguments: RideRequestArgs(requestId: ride.id, isMine: true),
          );
    route.then((_) => provider.load());
  }

  /// Up to three tiles; fewer families keep the tile width of three.
  Widget _families(BuildContext context, HomeProvider provider) {
    final families = provider.previewFamilies;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: i < families.length
                ? FamilyPreviewCard(
                    family: families[i],
                    onTap: () => _openFamilies(context),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }

  /// H1e / H3e.
  List<Widget> _emptyLayout(BuildContext context, HomeProvider provider) => [
    // H3e (both) uses the 44pt "Alerts" button; H1e keeps 48/22.
    _Header(provider: provider, compact: provider.role == HomeRole.both),
    const SizedBox(height: AppDimens.sectionGap),
    HomeHeroCard(
      illustration: provider.role == HomeRole.needsRides
          ? HomeAssets.heroNoRides
          : HomeAssets.heroNothingToday,
      title: provider.emptyTitle,
      subtitle: provider.emptySubtitle,
      onTap: provider.nextRide == null
          ? null
          : () => _openNextRide(context, provider),
    ),
    const SizedBox(height: AppDimens.sectionGap),
    AskRideActionCard(onTap: () => _askRide(context, provider)),
    ..._groupSection(context, provider),
    if (provider.previewFamilies.isNotEmpty) ...[
      const SizedBox(height: AppDimens.sectionGap),
      _FamiliesHeader(onSeeAll: () => _openFamilies(context)),
      const SizedBox(height: AppDimens.sectionGap),
      _families(context, provider),
    ],
  ];

  /// "Your ride group": the user's latest ride group, opening its chat.
  /// Empty when the user has no group.
  List<Widget> _groupSection(BuildContext context, HomeProvider provider) {
    final group = provider.latestGroup;
    if (group == null) return const [];
    return [
      const SizedBox(height: AppDimens.sectionGap),
      _GroupLabel(
        onSeeAll: () => Navigator.pushNamed(
          context,
          AppRoutes.rideGroups,
        ).then((_) => provider.load()),
      ),
      const SizedBox(height: AppDimens.sectionGap),
      RideGroupCard(
        title: group.name,
        subtitle: group.membersLabel,
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.groupChat,
          arguments: GroupChatArgs(groupId: group.id, name: group.name),
        ).then((_) => provider.load()),
      ),
    ];
  }

  /// H3 · Home · Both (get & give).
  List<Widget> _rideLayout(BuildContext context, HomeProvider provider) {
    final ride = provider.featuredRide!;
    final groupTitle = provider.rideGroupTitle;
    return [
      _Header(provider: provider, compact: true),
      const SizedBox(height: AppDimens.sectionGap),
      Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                provider.featuredSectionTitle,
                style: HomeTextStyles.sectionTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AppBadge(label: provider.featuredBadge),
        ],
      ),
      const SizedBox(height: AppDimens.sectionGap),
      HomeRideMapCard(
        headline: provider.featuredHeadline,
        avatarInitials: provider.featuredAvatarInitials,
        avatarUrl: provider.featuredAvatarUrl,
        destination: provider.featuredDestination,
        pickupLabel: provider.featuredPickupLabel,
        onTrack: () => Navigator.pushNamed(
          context,
          AppRoutes.liveTracking,
          arguments: RideArgs(ride.id),
        ).then((_) => provider.load()),
      ),
      const SizedBox(height: AppDimens.sectionGap),
      AskRideActionCard(onTap: () => _askRide(context, provider)),
      if (provider.latestGroup != null)
        ..._groupSection(context, provider)
      else if (groupTitle != null) ...[
        const SizedBox(height: AppDimens.sectionGap),
        const _GroupLabel(),
        const SizedBox(height: AppDimens.sectionGap),
        // No ride group yet: the route's parents, informational only.
        RideGroupCard(title: groupTitle, subtitle: provider.rideGroupSubtitle),
      ],
      if (provider.previewFamilies.isNotEmpty) ...[
        const SizedBox(height: AppDimens.sectionGap),
        _FamiliesHeader(onSeeAll: () => _openFamilies(context)),
        const SizedBox(height: AppDimens.sectionGap),
        _families(context, provider),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.screen,
        body: AppLoadingOverlay(
          isLoading: provider.isLoading,
          child: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: RefreshIndicator(
                  onRefresh: provider.load,
                  color: AppColors.ink,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      18,
                      6,
                      18,
                      AppBottomNav.height + bottomInset,
                    ),
                    children: provider.hasFeaturedRide
                        ? _rideLayout(context, provider)
                        : _emptyLayout(context, provider),
                  ),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AppBottomNav(current: AppTab.home),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.provider, this.compact = false});

  final HomeProvider provider;

  /// H3 and H3e use the 44pt "Alerts" button with a 24pt bell; H1e uses
  /// 48/22.
  final bool compact;

  /// "Log out?" confirmation, then sign out and back to the phone screen.
  Future<void> _logOut(BuildContext context) async {
    final ok = await showProfileConfirm(
      context,
      title: 'Log out?',
      message: 'You’ll need your phone number to sign in again.',
      confirmLabel: 'Log out',
    );
    if (!ok || !context.mounted) return;
    final result = await sl<SignOut>()(const NoParams());
    if (!context.mounted) return;
    final failure = result.getLeft().toNullable();
    if (failure != null) return showAppSnack(context, failure.message);
    resetSessionState();
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.phoneNumber, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(provider.dateLabel, style: HomeTextStyles.dateLabel),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(provider.greeting, style: HomeTextStyles.greeting),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox.square(
          dimension: compact ? 44 : 48,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleIconButton(
                asset: compact ? HomeAssets.bell : HomeAssets.iconBell,
                tooltip: provider.hasUnseenNotifications
                    ? 'Notifications, new'
                    : 'Notifications',
                size: compact ? 44 : 48,
                iconSize: compact ? 24 : 22,
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.notifications,
                ).then((_) => provider.load()),
              ),
              if (provider.hasUnseenNotifications)
                Positioned(
                  left: compact ? 30 : 33,
                  top: 2,
                  child: const IgnorePointer(
                    child: AppIcon(HomeAssets.alertDot, size: 12),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Log out (was the initials avatar).
        SizedBox.square(
          dimension: compact ? 44 : 48,
          child: Material(
            color: AppColors.lime,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Log out',
              onPressed: () => _logOut(context),
              icon: const Icon(
                Icons.power_settings_new_rounded,
                color: AppColors.ink,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FamiliesHeader extends StatelessWidget {
  const _FamiliesHeader({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text('FAMILIES', style: HomeTextStyles.captionS),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSeeAll,
            child: Semantics(
              button: true,
              child: Text('See all', style: HomeTextStyles.labelM),
            ),
          ),
        ],
      ),
    );
  }
}

/// "YOUR RIDE GROUP" section label, with "See all" when the user has
/// groups (opens the Ride groups list).
class _GroupLabel extends StatelessWidget {
  const _GroupLabel({this.onSeeAll});

  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text('YOUR RIDE GROUP', style: HomeTextStyles.groupLabel),
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSeeAll,
              child: Semantics(
                button: true,
                label: 'See all ride groups',
                excludeSemantics: true,
                child: Text('See all', style: HomeTextStyles.labelM),
              ),
            ),
        ],
      ),
    );
  }
}
