import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/widgets/app_badge.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_bottom_nav.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../core/constants/home_assets.dart';
import '../../core/constants/home_text_styles.dart';
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
    return ChangeNotifierProvider<HomeProvider>.value(
      value: provider,
      child: const _HomeView(),
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
    _Header(provider: provider),
    const SizedBox(height: AppDimens.sectionGap),
    HomeHeroCard(
      illustration: provider.role == HomeRole.needsRides
          ? HomeAssets.heroNoRides
          : HomeAssets.heroNothingToday,
      title: provider.emptyTitle,
      subtitle: provider.emptySubtitle,
    ),
    const SizedBox(height: AppDimens.sectionGap),
    AskRideActionCard(onTap: () => _askRide(context, provider)),
    if (provider.previewFamilies.isNotEmpty) ...[
      const SizedBox(height: AppDimens.sectionGap),
      _FamiliesHeader(onSeeAll: () => _openFamilies(context)),
      const SizedBox(height: AppDimens.sectionGap),
      _families(context, provider),
    ],
  ];

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
      if (groupTitle != null) ...[
        const SizedBox(height: AppDimens.sectionGap),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Semantics(
            header: true,
            child: Text('YOUR RIDE GROUP', style: HomeTextStyles.groupLabel),
          ),
        ),
        const SizedBox(height: AppDimens.sectionGap),
        // No group chat screen yet: the row is informational only.
        RideGroupCard(title: groupTitle, subtitle: provider.rideGroupSubtitle),
      ],
      if (provider.previewFamilies.isNotEmpty) ...[
        const SizedBox(height: AppDimens.sectionGap),
        _FamiliesHeader(
          onSeeAll: () => _openFamilies(context),
          style: HomeTextStyles.captionS,
        ),
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

  /// H3 uses the 44pt "Alerts" button with a 24pt bell; H1e/H3e use 48/22.
  final bool compact;

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
                onPressed: provider.markNotificationsSeen,
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
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.lime,
            shape: BoxShape.circle,
          ),
          child: Text(provider.initials, style: HomeTextStyles.labelM),
        ),
      ],
    );
  }
}

class _FamiliesHeader extends StatelessWidget {
  const _FamiliesHeader({required this.onSeeAll, this.style});

  final VoidCallback onSeeAll;

  /// Label style; defaults to Caption/M (H1e/H3e).
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text('FAMILIES', style: style ?? HomeTextStyles.captionM),
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
