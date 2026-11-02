import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../core/constants/ride_tracking_assets.dart';
import '../../core/utils/ride_format.dart';
import '../../domain/entities/ride_tracking.dart';
import '../providers/ride_completed_provider.dart';
import '../widgets/ride_avatar.dart';
import '../widgets/ride_contact.dart';
import '../widgets/ride_state_view.dart';
import '../widgets/ride_styles.dart';
import '../widgets/thank_you_sheet.dart';
import '../widgets/trip_summary_card.dart';

/// F23 · Ride completed. Reads [RideArgs] from the route. The requesting
/// parent sees "Emma arrived at Lincoln Elementary" with Say thank you;
/// the Ride Partner sees "Dropped off!" (Jen's phone variant).
class RideCompletedScreen extends StatelessWidget {
  const RideCompletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.settingsOf(context)?.arguments;
    final requestId = args is RideArgs ? args.requestId : null;
    return ChangeNotifierProvider<RideCompletedProvider>(
      create: (_) => sl<RideCompletedProvider>()..open(requestId),
      child: const _RideCompletedView(),
    );
  }
}

class _RideCompletedView extends StatelessWidget {
  const _RideCompletedView();

  void _goHome(BuildContext context) => Navigator.of(
    context,
  ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);

  Future<void> _sayThanks(BuildContext context, RideTracking t) async {
    final provider = context.read<RideCompletedProvider>();
    final rating = await showThankYouSheet(
      context,
      name: t.driver?.firstName ?? 'your Ride Partner',
    );
    if (rating == null || !context.mounted) return;
    final error = await provider.sayThankYou(rating);
    if (!context.mounted) return;
    showAppSnack(
      context,
      error ?? 'Thanks sent to ${t.driver?.firstName ?? 'your Ride Partner'}!',
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RideCompletedProvider>();
    final tracking = provider.tracking;
    if (tracking == null) {
      if (provider.status.isFailure) {
        return RideStateView(
          title: provider.hasRide
              ? 'We couldn’t load this ride'
              : 'No ride to show',
          message: provider.errorMessage ?? 'Please try again.',
          onRetry: provider.hasRide ? provider.retry : null,
        );
      }
      return const Scaffold(
        backgroundColor: AppColors.screen,
        body: Center(child: AppLoader()),
      );
    }

    final isDriver = tracking.isDriver;
    final parentName = tracking.parent?.firstName ?? 'the parent';
    return Scaffold(
      backgroundColor: AppColors.screen,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: isDriver
                    ? const EdgeInsets.fromLTRB(20, 10, 20, 28)
                    : const EdgeInsets.fromLTRB(16, 4, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isDriver) ...[
                      _DriverHero(tracking: tracking),
                      const SizedBox(height: 14),
                      _ParentToldCard(tracking: tracking),
                      const SizedBox(height: 14),
                      TripSummaryCard(tracking: tracking, showDriver: false),
                    ] else ...[
                      _ParentHero(tracking: tracking),
                      const SizedBox(height: 16),
                      TripSummaryCard(tracking: tracking),
                    ],
                    const Spacer(),
                    const SizedBox(height: AppDimens.sectionGap),
                    if (isDriver) ...[
                      AppButton(
                        label: 'Done',
                        height: 64,
                        leading: const AppIcon(
                          RideTrackingAssets.done,
                          size: 22,
                        ),
                        onPressed: () => _goHome(context),
                      ),
                      const SizedBox(height: 14),
                      AppButton(
                        label: 'Message $parentName',
                        height: 64,
                        variant: AppButtonVariant.light,
                        leading: const AppIcon(
                          RideTrackingAssets.message,
                          size: 22,
                        ),
                        onPressed: () =>
                            RideContact.message(context, name: parentName),
                      ),
                    ] else ...[
                      AppButton(
                        label: provider.thanked
                            ? 'Thanks sent'
                            : 'Say thank you',
                        isLoading: provider.thanking,
                        onPressed: provider.thanked || tracking.driver == null
                            ? null
                            : () => _sayThanks(context, tracking),
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'Back to Home',
                        variant: AppButtonVariant.light,
                        onPressed: () => _goHome(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lime success mark: soft ring, lime disc, check.
class _SuccessMark extends StatelessWidget {
  const _SuccessMark({
    required this.outer,
    required this.inner,
    required this.icon,
    required this.iconSize,
  });

  final double outer;
  final double inner;
  final String icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: outer,
      height: outer,
      decoration: const BoxDecoration(
        color: AppColors.limeTint,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: inner,
        height: inner,
        decoration: const BoxDecoration(
          color: AppColors.lime,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: AppIcon(icon, size: iconSize),
      ),
    );
  }
}

class _InkPill extends StatelessWidget {
  const _InkPill({required this.label, this.leading});

  final String label;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(leading == null ? 12 : 10, 6, 14, 6),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Text(label, style: RideTextStyles.pill),
        ],
      ),
    );
  }
}

/// Icon + one line of secondary text, centered.
class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.iconSize,
    required this.text,
    required this.style,
  });

  final String icon;
  final double iconSize;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIcon(icon, size: iconSize),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

/// F23 (parent): "Ride completed · Emma arrived at Lincoln Elementary".
class _ParentHero extends StatelessWidget {
  const _ParentHero({required this.tracking});

  final RideTracking tracking;

  @override
  Widget build(BuildContext context) {
    final t = tracking;
    final kids = RideFormat.names(t.kidNames, fallback: 'Your kids');
    final driver = t.driver?.firstName ?? 'Your Ride Partner';
    final at = t.completedAt;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          const _SuccessMark(
            outer: 120,
            inner: 88,
            icon: RideTrackingAssets.successCheck,
            iconSize: 44,
          ),
          const SizedBox(height: 12),
          const _InkPill(label: 'Ride completed'),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              '$kids arrived at ${t.school.label}',
              textAlign: TextAlign.center,
              style: RideTextStyles.completedTitle,
            ),
          ),
          const SizedBox(height: 12),
          _InfoLine(
            icon: RideTrackingAssets.locationPin,
            iconSize: 16,
            text: [
              if (at != null) RideFormat.clock(at),
              '$driver confirmed drop-off',
            ].join(' · '),
            style: RideTextStyles.body15,
          ),
        ],
      ),
    );
  }
}

/// F23 (Ride Partner): "Dropped off! · Emma was dropped off safely".
class _DriverHero extends StatelessWidget {
  const _DriverHero({required this.tracking});

  final RideTracking tracking;

  @override
  Widget build(BuildContext context) {
    final t = tracking;
    final kids = RideFormat.names(t.kidNames, fallback: 'The kids');
    final verb = t.kids.length == 1 ? 'was' : 'were';
    final at = t.completedAt;
    return Column(
      children: [
        const _SuccessMark(
          outer: 96,
          inner: 70,
          icon: RideTrackingAssets.successCheckDriver,
          iconSize: 42,
        ),
        const SizedBox(height: 10),
        const _InkPill(
          label: 'Dropped off!',
          leading: AppIcon(RideTrackingAssets.checkSmall, size: 16),
        ),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text(
            '$kids $verb dropped off safely',
            textAlign: TextAlign.center,
            style: RideTextStyles.droppedOffTitle,
          ),
        ),
        const SizedBox(height: 10),
        _InfoLine(
          icon: RideTrackingAssets.locationPin18,
          iconSize: 18,
          text: [
            t.school.label,
            if (at != null) RideFormat.clock(at),
          ].join(' · '),
          style: RideTextStyles.body17,
        ),
        const SizedBox(height: 10),
        Text(
          'Thank you for helping a family today! 🙌',
          textAlign: TextAlign.center,
          style: RideTextStyles.rowLabel.copyWith(
            color: RideColors.muted,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

/// "Sarah has been told — She got “Emma arrived at school”".
class _ParentToldCard extends StatelessWidget {
  const _ParentToldCard({required this.tracking});

  final RideTracking tracking;

  @override
  Widget build(BuildContext context) {
    final parent = tracking.parent;
    final name = parent?.firstName ?? 'The parent';
    final kids = RideFormat.names(tracking.kidNames, fallback: 'The kids');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.limeTint,
        borderRadius: BorderRadius.circular(AppDimens.radiusRow),
      ),
      child: Row(
        children: [
          RideAvatar(
            initials: parent?.initials ?? RideFormat.initials(name),
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name has been told',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RideTextStyles.title17,
                ),
                const SizedBox(height: 1),
                Text(
                  'They got “$kids arrived at school”',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: RideTextStyles.body14,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.lime,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const AppIcon(RideTrackingAssets.bell, size: 18),
          ),
        ],
      ),
    );
  }
}
