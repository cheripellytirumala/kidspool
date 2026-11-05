import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_bottom_nav.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../core/constants/messages_api_constants.dart';
import '../../domain/entities/ride_chat.dart';
import '../../domain/entities/ride_request.dart';
import '../providers/messages_provider.dart';
import '../widgets/messages_common.dart';
import '../widgets/messages_list_widgets.dart';
import 'ride_request_detail_screen.dart';

/// F24 · Messages (Chats) and F24a · Requests — the Messages tab.
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MessagesProvider>(
      create: (_) => sl<MessagesProvider>()..load(),
      child: const _MessagesView(),
    );
  }
}

class _MessagesView extends StatelessWidget {
  const _MessagesView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MessagesProvider>();
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Text('Messages', style: AppTextStyles.displayL),
      ),
      MessagesSearchField(onChanged: provider.search),
      MessagesTabs(
        current: provider.tab,
        requestsBadge: provider.requestsBadge,
        chatsBadge: provider.chatsBadge,
        onSelected: provider.selectTab,
      ),
      ...switch (provider.tab) {
        MessagesTab.requests => _requests(context, provider),
        MessagesTab.chats => _chats(context, provider),
      },
    ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.screen,
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: AppColors.ink,
                onRefresh: provider.refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    AppBottomNav.height + bottomInset + 16,
                  ),
                  itemCount: children.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => children[i],
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AppBottomNav(current: AppTab.messages),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------- requests

  List<Widget> _requests(BuildContext context, MessagesProvider provider) {
    final incoming = provider.incoming;
    final mine = provider.mine;
    if (incoming.isEmpty && mine.isEmpty) {
      if (provider.requestsStatus.isLoading ||
          provider.requestsStatus.isInitial) {
        return const [_TabLoader()];
      }
      if (provider.requestsStatus.isFailure) {
        return [
          MessagesTabMessage(
            title: 'We couldn’t load requests',
            message: provider.requestsError ?? 'Please try again.',
            onRetry: provider.loadRequests,
          ),
        ];
      }
      return [
        MessagesTabMessage(
          title: provider.query.isEmpty ? 'No requests right now' : 'No match',
          message: provider.query.isEmpty
              ? 'Ride requests from nearby parents and offers on your '
                    'rides show up here.'
              : 'Try a different name or place.',
        ),
      ];
    }
    return [
      if (incoming.isNotEmpty) ...[
        MessagesSectionLabel('Ride requests · ${incoming.length}'),
        for (final r in incoming)
          IncomingRequestCard(
            request: r,
            busy: provider.busyId == r.id,
            onOpen: () => _openRequest(context, r),
            onHelp: () => _offer(context, r),
            onPass: () => provider.pass(r),
            onWithdraw: () => _withdraw(context, r),
          ),
      ],
      if (mine.isNotEmpty) ...[
        MessagesSectionLabel('Your requests · ${mine.length}'),
        for (final r in mine)
          MyRequestCard(
            request: r,
            busyId: provider.busyId,
            onOpen: () => _openRequest(context, r),
            onOpenOffer: (o) => _openChat(
              context,
              RideChatArgs(
                requestId: r.id,
                driverId: o.partner.id ?? '',
                iAmDriver: false,
                otherName: o.partner.firstName,
                otherInitials: o.partner.initials,
              ),
            ),
            onRespond: (o, approve) => _respond(context, o, approve),
          ),
      ],
      const MessagesFootnote('Requests stay here until you answer.'),
    ];
  }

  // ------------------------------------------------------------- chats

  List<Widget> _chats(BuildContext context, MessagesProvider provider) {
    final chats = provider.chats;
    return [
      if (provider.chatMissing)
        const _Notice(MessagesApiConstants.chatMissingMessage),
      if (chats.isEmpty)
        if (provider.chatsStatus.isLoading ||
            provider.chatsStatus.isInitial ||
            provider.requestsStatus.isLoading)
          const _TabLoader()
        else if (provider.chatsStatus.isFailure)
          MessagesTabMessage(
            title: 'We couldn’t load your chats',
            message: provider.chatsError ?? 'Please try again.',
            onRetry: provider.loadChats,
          )
        else
          MessagesTabMessage(
            title: provider.query.isEmpty ? 'No chats yet' : 'No match',
            message: provider.query.isEmpty
                ? 'When you offer a ride or someone offers yours, you can '
                      'chat here.'
                : 'Try a different name.',
          ),
      for (final chat in chats)
        ChatListTile(
          chat: chat,
          place: provider.chatPlace(chat),
          onTap: () => _openChat(context, _argsOf(chat)),
        ),
    ];
  }

  static RideChatArgs _argsOf(RideChat chat) => RideChatArgs(
    requestId: chat.requestId,
    driverId: chat.driverId,
    iAmDriver: chat.iAmDriver,
    otherName: chat.other.firstName,
    otherInitials: chat.other.initials,
  );

  // ------------------------------------------------------------ actions

  Future<void> _openRequest(BuildContext context, RideRequest r) async {
    final provider = context.read<MessagesProvider>();
    await Navigator.of(context).pushNamed(
      AppRoutes.rideRequestDetail,
      arguments: RideRequestArgs(requestId: r.id, isMine: r.isMine),
    );
    await provider.loadRequests();
  }

  Future<void> _openChat(BuildContext context, RideChatArgs args) async {
    if (args.driverId.isEmpty) {
      showAppSnack(context, 'We couldn’t open this chat.');
      return;
    }
    final provider = context.read<MessagesProvider>();
    await Navigator.of(context).pushNamed(AppRoutes.rideChat, arguments: args);
    await provider.load();
  }

  Future<void> _offer(BuildContext context, RideRequest r) async {
    final provider = context.read<MessagesProvider>();
    final (outcome, error) = await provider.offer(r);
    if (!context.mounted) return;
    if (outcome == null) {
      if (error != null) showAppSnack(context, error);
      return;
    }
    final name = r.parent?.firstName ?? 'the parent';
    showAppSnack(
      context,
      outcome.confirmed
          ? 'Ride booked! $name has been told.'
          : 'Offer sent. $name will confirm.',
    );
    final me = provider.myUserId;
    if (me != null) {
      await _openChat(
        context,
        RideChatArgs(
          requestId: r.id,
          driverId: me,
          iAmDriver: true,
          otherName: r.parent?.firstName,
          otherInitials: r.parent?.initials,
        ),
      );
    }
  }

  Future<void> _withdraw(BuildContext context, RideRequest r) async {
    final error = await context.read<MessagesProvider>().withdraw(r);
    if (!context.mounted) return;
    showAppSnack(context, error ?? 'Offer withdrawn.');
  }

  Future<void> _respond(BuildContext context, RideOffer o, bool ok) async {
    final error = await context.read<MessagesProvider>().respond(
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
}

class _TabLoader extends StatelessWidget {
  const _TabLoader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(child: AppLoader(size: 56)),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.limeTint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '$text Rides you offered or were offered are still listed.',
        style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
      ),
    );
  }
}
