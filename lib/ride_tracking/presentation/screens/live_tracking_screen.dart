import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../core/constants/ride_tracking_assets.dart';
import '../../core/utils/ride_format.dart';
import '../../domain/entities/ride_tracking.dart';
import '../providers/live_tracking_provider.dart';
import '../widgets/live_tracking_sheet.dart';
import '../widgets/ride_buttons.dart';
import '../widgets/ride_contact.dart';
import '../widgets/ride_map.dart';
import '../widgets/ride_start_view.dart';
import '../widgets/ride_state_view.dart';
import '../widgets/ride_styles.dart';

/// F22 · Live tracking. Reads [RideArgs] from the route; the requesting
/// parent watches the car, the Ride Partner also gets Start ride /
/// Picked up / Dropped off. Moves on to F23 once the ride is completed.
class LiveTrackingScreen extends StatelessWidget {
  const LiveTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.settingsOf(context)?.arguments;
    final requestId = args is RideArgs ? args.requestId : null;
    return ChangeNotifierProvider<LiveTrackingProvider>(
      create: (_) => sl<LiveTrackingProvider>()..open(requestId),
      child: const _LiveTrackingView(),
    );
  }
}

class _LiveTrackingView extends StatefulWidget {
  const _LiveTrackingView();

  @override
  State<_LiveTrackingView> createState() => _LiveTrackingViewState();
}

class _LiveTrackingViewState extends State<_LiveTrackingView>
    with WidgetsBindingObserver {
  /// Below this height the header + sheet may not fit without scrolling.
  static const double _scrollBelow = 700;

  bool _leaving = false;

  LiveTrackingProvider get _provider => context.read<LiveTrackingProvider>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _provider.resume();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _provider.pause();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _maybeShowCompleted(RideTracking? tracking) {
    if (_leaving || tracking == null || !tracking.completed) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.rideCompleted,
        arguments: RideArgs(tracking.requestId),
      );
    });
  }

  Future<void> _onDriverAction() async {
    final error = await _provider.runDriverAction();
    if (error != null && mounted) showAppSnack(context, error);
  }

  Future<void> _onSos(RideTracking tracking) async {
    final other = tracking.isDriver ? tracking.parent : tracking.driver;
    final send = await RideContact.confirmSos(
      context,
      otherName:
          other?.firstName ??
          (tracking.isDriver ? 'the parent' : 'your Ride Partner'),
    );
    if (!send || !mounted) return;
    final error = await _provider.sendSos();
    if (!mounted) return;
    showAppSnack(
      context,
      error ?? 'SOS sent. ${other?.firstName ?? 'They'} can see it now.',
    );
  }

  RidePerson? _otherPerson(RideTracking t) => t.isDriver ? t.parent : t.driver;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LiveTrackingProvider>();
    final tracking = provider.tracking;
    _maybeShowCompleted(tracking);

    if (tracking == null) {
      if (provider.status.isFailure) {
        return RideStateView(
          dark: true,
          title: provider.hasRide
              ? 'We couldn’t load this ride'
              : 'No ride to show',
          message: provider.errorMessage ?? 'Please try again.',
          onRetry: provider.hasRide ? provider.retry : null,
        );
      }
      return const Scaffold(
        backgroundColor: AppColors.inverse,
        body: Center(child: AppLoader()),
      );
    }
    if (tracking.closed) {
      return RideStateView(
        dark: true,
        title: switch (tracking.status) {
          RideTrackingStatus.cancelled => 'This ride was cancelled',
          RideTrackingStatus.missed => 'This ride was missed',
          _ => 'This ride has expired',
        },
        message: 'There’s nothing to track for this ride any more.',
      );
    }

    final other = _otherPerson(tracking);
    final otherName =
        other?.firstName ??
        (tracking.isDriver ? 'the parent' : 'your Ride Partner');
    void onMessage() => RideContact.message(context, tracking);
    void onCall() =>
        RideContact.call(context, name: otherName, phone: other?.phone);

    // F20 · The Ride Partner before the ride starts.
    if (provider.driverAction == DriverRideAction.start) {
      return RideStartView(
        tracking: tracking,
        busy: provider.busyAction != null,
        onStart: _onDriverAction,
        onMessage: onMessage,
        onCall: onCall,
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.inverse,
        body: Stack(
          children: [
            Positioned.fill(
              child: RideMap(
                tracking: tracking,
                padding: EdgeInsets.only(
                  top: MediaQuery.viewPaddingOf(context).top + 220,
                  bottom: 300,
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, box) {
                final content = Column(
                  children: [
                    SafeArea(
                      bottom: false,
                      child: _Header(
                        tracking: tracking,
                        sendingSos: provider.sendingSos,
                        onBack: () => Navigator.of(context).maybePop(),
                        onSos: () => _onSos(tracking),
                      ),
                    ),
                    // Empty space lets touches through to the map.
                    const Spacer(),
                    const SizedBox(height: 24),
                    LiveTrackingSheet(
                      tracking: tracking,
                      driverAction: provider.driverAction,
                      busyAction: provider.busyAction,
                      onDriverAction: _onDriverAction,
                      onMessage: onMessage,
                      onCall: onCall,
                    ),
                  ],
                );
                // Tall phones: a plain column, so the map stays draggable.
                // Short ones: scroll rather than overflow.
                if (box.maxHeight >= _scrollBelow) return content;
                return CustomScrollView(
                  slivers: [
                    SliverFillRemaining(hasScrollBody: false, child: content),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Back + SOS, the headline and the status pill.
class _Header extends StatelessWidget {
  const _Header({
    required this.tracking,
    required this.sendingSos,
    required this.onBack,
    required this.onSos,
  });

  final RideTracking tracking;
  final bool sendingSos;
  final VoidCallback onBack;
  final VoidCallback onSos;

  (String, String) get _headline {
    final t = tracking;
    final kids = RideFormat.names(t.kidNames, fallback: 'Your kids');
    final verb = t.kids.length > 1 ? 'are' : 'is';
    final driver = t.driver?.firstName ?? 'Your Ride Partner';
    if (t.isDriver) {
      if (!t.started) {
        return ('Pick up $kids', 'at ${RideFormat.clock(t.pickupAt)}');
      }
      if (!t.pickedUp) return ('Heading to', '${t.pickup.label}…');
      return ('Driving $kids', 'to ${t.destination.label}…');
    }
    if (!t.started) {
      return ('$driver picks up $kids', 'at ${RideFormat.clock(t.pickupAt)}');
    }
    if (!t.pickedUp) return ('$driver is on the way', 'to pick up $kids…');
    return ('$kids $verb heading', 'to ${t.destination.label}…');
  }

  String get _pill {
    final t = tracking;
    if (t.pickedUpAt case final at?) {
      return 'Picked up at ${t.pickup.label} · ${RideFormat.clock(at)}';
    }
    if (t.startedAt case final at?) {
      return 'Ride started · ${RideFormat.clock(at)}';
    }
    return 'Pickup at ${t.pickup.label} · ${RideFormat.clock(t.pickupAt)}';
  }

  @override
  Widget build(BuildContext context) {
    final (line1, line2) = _headline;
    final width = MediaQuery.sizeOf(context).width;
    // Display/L is 44px on a 390pt phone; scale down on narrow screens.
    final size = (width * 44 / 390).clamp(32.0, 44.0);
    final headline = AppTextStyles.displayL.copyWith(
      fontSize: size,
      height: 1,
      letterSpacing: -size * 0.03,
      color: AppColors.textOnDark,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RideIconButton.back(onPressed: onBack),
              RideSosButton(onPressed: onSos, busy: sendingSos),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                label: '$line1 $line2',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The kids' names must stay whole: shrink rather than cut.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(line1, maxLines: 1, style: headline),
                    ),
                    Text(
                      line2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: headline.copyWith(color: AppColors.lime),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _StatusPill(text: _pill),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.lime,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const AppIcon(
              RideTrackingAssets.shield,
              size: 14,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RideTextStyles.labelM,
            ),
          ),
        ],
      ),
    );
  }
}
