import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../core/constants/messages_styles.dart';
import '../../core/utils/messages_format.dart';
import '../../domain/entities/ride_request.dart';
import '../providers/ride_request_detail_provider.dart';
import '../widgets/messages_common.dart';
import '../widgets/messages_list_widgets.dart';

/// Route arguments for [RideRequestDetailScreen] (A7a).
class RideRequestArgs {
  const RideRequestArgs({required this.requestId, this.isMine = false});

  /// `ride_requests.id`.
  final String requestId;

  /// The signed-in user asked for this ride (else it was sent to them as a
  /// Ride Partner).
  final bool isMine;
}

/// A7a · "Sarah needs a ride for Emma" — the Ride Partner's view of an
/// incoming request (Yes, I can help / Can't this time). For the user's own
/// request it lists the offers to approve and lets them cancel.
class RideRequestDetailScreen extends StatelessWidget {
  const RideRequestDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.settingsOf(context)?.arguments;
    final a = args is RideRequestArgs ? args : null;
    return ChangeNotifierProvider<RideRequestDetailProvider>(
      create: (_) =>
          sl<RideRequestDetailProvider>()
            ..open(a?.requestId, isMine: a?.isMine ?? false),
      child: const _DetailView(),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RideRequestDetailProvider>();
    final request = provider.request;
    if (request == null) {
      if (provider.status.isFailure) {
        return MessagesStateScreen(
          title: provider.hasRequest
              ? 'We couldn’t load this request'
              : 'No request to show',
          message: provider.errorMessage ?? 'Please try again.',
          onRetry: provider.hasRequest ? provider.retry : null,
        );
      }
      return const MessagesLoadingScreen();
    }
    return Scaffold(
      backgroundColor: AppColors.screen,
      body: SafeArea(
        child: AppLoadingOverlay(
          isLoading: provider.busy,
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  child: request.isMine
                      ? _MineBody(request: request)
                      : _IncomingBody(request: request),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: MessagesBackButton(),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(text, style: AppTextStyles.displayL),
    );
  }
}

/// Surface row: avatar + title + subtitle (A7a "Frame" / "Ride summary").
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.leading,
    required this.title,
    required this.subtitle,
  });

  final Widget leading;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(MessagesStyles.radiusRow),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: MessagesStyles.summaryTitle),
                const SizedBox(height: 1),
                Text(subtitle, style: MessagesStyles.summaryMeta),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _when(RideRequest r) => [
  MessagesFormat.dayAndTime(r.pickupAt),
  if (r.repeats) '${r.openDaysInSeries} days',
].join(' · ');

Widget _kidAvatar(RideRequest r) {
  final kid = r.kids.isEmpty ? null : r.kids.first;
  return MessagesAvatar(
    initials: kid?.initial ?? '?',
    photoUrl: kid?.photoUrl,
    size: 40,
    background: AppColors.limeTint,
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.lime,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: MessagesStyles.summaryMeta.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: MessagesStyles.limeSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text('“$text”', style: MessagesStyles.note),
    );
  }
}

// ------------------------------------------------- Ride Partner (A7a)

class _IncomingBody extends StatelessWidget {
  const _IncomingBody({required this.request});

  final RideRequest request;

  Future<void> _offer(BuildContext context) async {
    final provider = context.read<RideRequestDetailProvider>();
    final navigator = Navigator.of(context);
    final me = provider.myUserId;
    final (outcome, error) = await provider.offer();
    if (!context.mounted) return;
    if (outcome == null) {
      if (error != null) showAppSnack(context, error);
      return;
    }
    final name = request.parent?.firstName ?? 'the parent';
    showAppSnack(
      context,
      outcome.confirmed
          ? 'Ride booked! $name has been told.'
          : 'Offer sent. $name will confirm.',
    );
    if (me != null) {
      navigator.pushReplacementNamed(
        AppRoutes.rideChat,
        arguments: RideChatArgs(
          requestId: request.id,
          driverId: me,
          iAmDriver: true,
          otherName: request.parent?.firstName,
          otherInitials: request.parent?.initials,
        ),
      );
    }
  }

  Future<void> _pass(BuildContext context) async {
    final navigator = Navigator.of(context);
    await context.read<RideRequestDetailProvider>().pass();
    navigator.maybePop();
  }

  Future<void> _withdraw(BuildContext context) async {
    final error = await context.read<RideRequestDetailProvider>().withdraw();
    if (!context.mounted) return;
    showAppSnack(context, error ?? 'Offer withdrawn.');
  }

  @override
  Widget build(BuildContext context) {
    final parent = request.parent;
    final name = parent?.firstName ?? 'A parent';
    final kids = MessagesFormat.names(request.kidNames, fallback: 'their kids');
    final firstKid = request.kidNames.isEmpty ? null : request.kidNames.first;
    final parentLine = [
      parent?.shortName ?? name,
      if (firstKid != null) '$firstKid’s parent',
    ].join(' · ');
    final parentMeta = [
      if (parent != null && parent.kidsAtSchool.isNotEmpty)
        'Kids at ${request.destinationName}',
      if (request.distanceMiles != null)
        MessagesFormat.miles(request.distanceMiles!),
    ];
    final booked = request.status.isBooked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TopBar(),
        const SizedBox(height: 12),
        _Headline('$name needs a ride for ${firstKid ?? kids}'),
        const SizedBox(height: 12),
        _SummaryRow(
          leading: MessagesAvatar(
            initials: parent?.initials ?? '?',
            photoUrl: parent?.photoUrl,
            size: 44,
            background: AppColors.screen,
          ),
          title: parentLine,
          subtitle: parentMeta.isEmpty
              ? 'Nearby parent'
              : parentMeta.join(' · '),
        ),
        const SizedBox(height: 12),
        _SummaryRow(
          leading: _kidAvatar(request),
          title: '$kids · ${request.pickupLabel} → ${request.destinationName}',
          subtitle: _when(request),
        ),
        if (request.note != null) ...[
          const SizedBox(height: 12),
          _Note(request.note!),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (request.repeats) const _Chip('Repeats weekly'),
            if (request.needsBooster) const _Chip('Booster seat'),
            if (request.youAreBusy) const _Chip('You have a ride then'),
            if (request.offered) const _Chip('Offer sent'),
            if (booked) const _Chip('You drive this ride'),
          ],
        ),
        const Spacer(),
        const SizedBox(height: 12),
        if (booked)
          AppButton(
            label: 'Open live ride',
            onPressed: () => Navigator.of(context).pushNamed(
              AppRoutes.liveTracking,
              arguments: RideArgs(request.id),
            ),
          )
        else if (request.offered) ...[
          AppButton(
            label: 'Withdraw my offer',
            variant: AppButtonVariant.light,
            onPressed: () => _withdraw(context),
          ),
        ] else if (request.isOpen) ...[
          AppButton(label: 'Yes, I can help', onPressed: () => _offer(context)),
          const SizedBox(height: 12),
          MessagesPillButton(
            label: 'Can’t this time',
            background: AppColors.surface,
            height: 48,
            onPressed: () => _pass(context),
          ),
        ] else
          Text(
            'This request isn’t open any more.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
      ],
    );
  }
}

// ---------------------------------------------------- own request

class _MineBody extends StatelessWidget {
  const _MineBody({required this.request});

  final RideRequest request;

  Future<void> _respond(BuildContext context, RideOffer o, bool ok) async {
    final error = await context.read<RideRequestDetailProvider>().respond(
      o,
      approve: ok,
    );
    if (!context.mounted) return;
    showAppSnack(
      context,
      error ??
          (ok ? 'Ride booked with ${o.partner.firstName}!' : 'Offer declined.'),
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final provider = context.read<RideRequestDetailProvider>();
    final ok = await confirmMessagesAction(
      context,
      title: 'Cancel this request?',
      message: 'Ride Partners won’t see it any more.',
      confirm: 'Cancel request',
    );
    if (!ok || !context.mounted) return;
    final error = await provider.cancel();
    if (!context.mounted) return;
    showAppSnack(context, error ?? 'Request cancelled.');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RideRequestDetailProvider>();
    final kids = MessagesFormat.names(request.kidNames, fallback: 'your kids');
    final notified = provider.activity?.notifiedCount ?? 0;
    final driver = request.driver;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TopBar(),
        const SizedBox(height: 12),
        _Headline('Your ride for $kids'),
        const SizedBox(height: 12),
        _SummaryRow(
          leading: _kidAvatar(request),
          title: '$kids · ${request.pickupLabel} → ${request.destinationName}',
          subtitle: _when(request),
        ),
        if (notified > 0) ...[
          const SizedBox(height: 12),
          _Note(
            'Sent to $notified ${notified == 1 ? 'family' : 'families'} '
            'near you.',
          ),
        ],
        if (driver != null && request.status.isBooked) ...[
          const SizedBox(height: 12),
          _SummaryRow(
            leading: MessagesAvatar(
              initials: driver.initials,
              photoUrl: driver.photoUrl,
              size: 44,
            ),
            title: '${driver.shortName} drives',
            subtitle: 'Ride booked',
          ),
        ],
        for (final offer in request.offers) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MessagesStyles.limeSoft,
              borderRadius: BorderRadius.circular(MessagesStyles.radiusRequest),
            ),
            child: OfferRow(
              offer: offer,
              busy: false,
              onOpen: () => Navigator.of(context).pushNamed(
                AppRoutes.rideChat,
                arguments: RideChatArgs(
                  requestId: request.id,
                  driverId: offer.partner.id ?? '',
                  iAmDriver: false,
                  otherName: offer.partner.firstName,
                  otherInitials: offer.partner.initials,
                ),
              ),
              onApprove: () => _respond(context, offer, true),
              onDecline: () => _respond(context, offer, false),
            ),
          ),
        ],
        if (request.isOpen && request.offers.isEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'No offers yet — we’ll let you know.',
            style: AppTextStyles.body,
          ),
        ],
        const Spacer(),
        const SizedBox(height: 12),
        // The parent's live map opens once the driver starts the ride.
        if (request.status == RideRequestStatus.confirmed)
          Text(
            'Booked. Live tracking opens when your Ride Partner starts the '
            'ride.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
        if (request.status == RideRequestStatus.inProgress)
          AppButton(
            label: 'Open live ride',
            onPressed: () => Navigator.of(context).pushNamed(
              AppRoutes.liveTracking,
              arguments: RideArgs(request.id),
            ),
          ),
        if (request.isOpen || request.status == RideRequestStatus.confirmed)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: MessagesPillButton(
              label: request.isOpen ? 'Cancel request' : 'Cancel ride',
              background: AppColors.surface,
              height: 48,
              onPressed: () => _cancel(context),
            ),
          ),
        if (request.status == RideRequestStatus.cancelled)
          Text(
            'This request was cancelled.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
      ],
    );
  }
}
