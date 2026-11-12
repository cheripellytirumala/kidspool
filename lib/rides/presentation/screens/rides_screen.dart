import '../../../common/presentation/state/live_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_bottom_nav.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../../common/presentation/widgets/app_toggle.dart';
import '../../../messages/core/utils/messages_format.dart';
import '../../../messages/domain/entities/ride_request.dart';
import '../../../messages/presentation/screens/ride_request_detail_screen.dart';
import '../../../messages/presentation/widgets/messages_list_widgets.dart';
import '../../core/constants/rides_styles.dart';
import '../providers/rides_provider.dart';
import '../widgets/ride_list_card.dart';

/// F19c · Your rides (Rides tab).
///
/// * Requests — open requests sent to the user as a Ride Partner
///   (`get_open_requests` + pending offers), behind the "Available to help
///   families near you" toggle (ride mode: get & give rides).
/// * Upcoming — the user's own requests and the rides they drive.
/// * Past — finished, cancelled, expired or missed rides.
class RidesScreen extends StatelessWidget {
  const RidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RidesProvider>(
      create: (_) => sl<RidesProvider>()..load(),
      child: Builder(
        builder: (context) => LiveRefreshListener(
          onRefresh: () => context.read<RidesProvider>().load(silent: true),
          child: const _RidesView(),
        ),
      ),
    );
  }
}

class _RidesView extends StatelessWidget {
  const _RidesView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RidesProvider>();
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
                      16,
                      4,
                      16,
                      AppBottomNav.height + bottomInset + 18,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                'Your rides',
                                style: AppTextStyles.displayL,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Requests to help, upcoming rides and history',
                              style: RidesStyles.subtitle,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Tabs(provider: provider),
                      ..._tabBody(context, provider),
                    ],
                  ),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AppBottomNav(current: AppTab.rides),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _tabBody(BuildContext context, RidesProvider provider) {
    final tab = provider.tab;
    final state = provider.current;
    final actions = _RideActions(context, provider);
    final body = <Widget>[];

    if (tab == RidesTab.requests) {
      body.add(
        _AvailableRow(
          value: provider.available,
          onChanged: (v) async {
            final error = await provider.setAvailable(v);
            if (error != null && context.mounted) showAppSnack(context, error);
          },
        ),
      );
      if (!provider.available) {
        body.add(
          const MessagesTabMessage(
            title: 'You’re not helping right now',
            message:
                'Turn this on to see ride requests from families near you.',
          ),
        );
        return _gapped(body);
      }
    }

    if (!state.loaded) return _gapped(body);
    if (state.error != null) {
      body.add(
        MessagesTabMessage(
          title: 'Couldn’t load your rides',
          message: state.error!,
          onRetry: provider.load,
        ),
      );
      return _gapped(body);
    }
    if (state.items.isEmpty) {
      body.add(switch (tab) {
        RidesTab.requests => const MessagesTabMessage(
          title: 'No requests right now',
          message: 'When families near you ask for a ride, it shows up here.',
        ),
        RidesTab.upcoming => const MessagesTabMessage(
          title: 'No upcoming rides',
          message: 'Ask for a ride from Home, or help a family in Requests.',
        ),
        RidesTab.past => const MessagesTabMessage(
          title: 'No past rides yet',
          message: 'Finished rides show up here.',
        ),
      });
      return _gapped(body);
    }

    body.add(
      Semantics(
        header: true,
        child: Text(switch (tab) {
          RidesTab.requests => 'NEW REQUESTS',
          RidesTab.upcoming => 'COMING UP',
          RidesTab.past => 'HISTORY',
        }, style: RidesStyles.meta),
      ),
    );
    for (final ride in state.items) {
      body.add(switch (tab) {
        RidesTab.requests => _requestCard(ride, actions),
        RidesTab.upcoming || RidesTab.past => _rideCard(ride, actions),
      });
    }
    return _gapped(body);
  }

  static List<Widget> _gapped(List<Widget> children) => [
    for (final c in children) ...[const SizedBox(height: 12), c],
  ];

  Widget _requestCard(RideRequest ride, _RideActions actions) {
    return RideListCard(
      ride: ride,
      badge: ride.offered
          ? 'You offered'
          : (ride.repeats ? 'Repeats weekly' : null),
      badgeTone: ride.offered ? RideBadgeTone.white : RideBadgeTone.lime,
      chips: [
        if (ride.distanceMiles != null)
          '${MessagesFormat.miles(ride.distanceMiles!)} from you',
        if (ride.needsBooster) 'Booster seat',
        if (ride.youAreBusy) 'You have a ride then',
      ],
      actionLabel: 'View request',
      onAction: () => actions.openRequest(ride),
    );
  }

  Widget _rideCard(RideRequest ride, _RideActions actions) {
    final (badge, tone) = switch (ride.status) {
      RideRequestStatus.open => ('Asking', RideBadgeTone.neutral),
      RideRequestStatus.confirmed => ('Booked', RideBadgeTone.lime),
      RideRequestStatus.inProgress => ('On the way', RideBadgeTone.lime),
      RideRequestStatus.completed => ('Done', RideBadgeTone.white),
      RideRequestStatus.cancelled => ('Cancelled', RideBadgeTone.neutral),
      RideRequestStatus.expired => ('No match', RideBadgeTone.neutral),
      RideRequestStatus.missed => ('Missed', RideBadgeTone.neutral),
    };
    final (label, action) = switch (ride.status) {
      // Parent: no live map until the driver starts the ride.
      RideRequestStatus.confirmed when ride.isMine => (null, null),
      RideRequestStatus.confirmed || RideRequestStatus.inProgress => (
        ride.isMine ? 'Track ride' : 'Open ride',
        () => actions.track(ride),
      ),
      RideRequestStatus.open => (
        'View request',
        () => actions.openRequest(ride),
      ),
      RideRequestStatus.completed => (
        'See ride summary',
        () => actions.summary(ride),
      ),
      _ => (null, null),
    };
    return RideListCard(
      ride: ride,
      badge: badge,
      badgeTone: tone,
      chips: [
        if (!ride.isMine) 'You drive',
        if (ride.repeats && !ride.status.isOver) 'Repeats weekly',
      ],
      actionLabel: label,
      onAction: action,
      onTap: action ?? () => actions.openRequest(ride),
    );
  }
}

/// Navigation from a card; reloads the tab on return.
class _RideActions {
  const _RideActions(this.context, this.provider);

  final BuildContext context;
  final RidesProvider provider;

  Future<void> _push(String route, Object args) async {
    await Navigator.pushNamed(context, route, arguments: args);
    await provider.load();
  }

  void openRequest(RideRequest ride) => _push(
    AppRoutes.rideRequestDetail,
    RideRequestArgs(requestId: ride.id, isMine: ride.isMine),
  );

  void track(RideRequest ride) =>
      _push(AppRoutes.liveTracking, RideArgs(ride.id));

  void summary(RideRequest ride) =>
      _push(AppRoutes.rideCompleted, RideArgs(ride.id));
}

/// F19c "Tabs": surface pill, ink selected segment.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.provider});

  final RidesProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final (i, tab) in RidesTab.values.indexed) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(child: _tab(tab)),
          ],
        ],
      ),
    );
  }

  Widget _tab(RidesTab tab) {
    final selected = provider.tab == tab;
    final name = switch (tab) {
      RidesTab.requests => 'Requests',
      RidesTab.upcoming => 'Upcoming',
      RidesTab.past => 'Past',
    };
    final count = provider.countOf(tab);
    final label = count == null ? name : '$name · $count';
    return Semantics(
      selected: selected,
      button: true,
      label: count == null ? name : '$name, $count',
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.ink : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: () => provider.selectTab(tab),
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: RidesStyles.labelM.copyWith(
                    color: selected
                        ? AppColors.textOnDark
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lime-soft pill: "Available to help families near you" + Toggle.
class _AvailableRow extends StatelessWidget {
  const _AvailableRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.limeTint,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Available to help families near you',
                style: RidesStyles.labelM,
              ),
            ),
            const SizedBox(width: 12),
            AppToggle(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
