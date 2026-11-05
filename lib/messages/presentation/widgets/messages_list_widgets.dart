import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/messages_assets.dart';
import '../../core/constants/messages_styles.dart';
import '../../core/utils/messages_format.dart';
import '../../domain/entities/ride_chat.dart';
import '../../domain/entities/ride_request.dart';
import '../providers/messages_provider.dart';
import 'messages_common.dart';

/// F24 search pill ("Search messages").
class MessagesSearchField extends StatelessWidget {
  const MessagesSearchField({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          const AppIcon(MessagesAssets.search, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: MessagesStyles.labelM,
              cursorColor: AppColors.ink,
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Search messages',
                hintStyle: MessagesStyles.labelM.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// F24 / F24a segmented tabs: Requests · Chats with count badges.
class MessagesTabs extends StatelessWidget {
  const MessagesTabs({
    super.key,
    required this.current,
    required this.requestsBadge,
    required this.chatsBadge,
    required this.onSelected,
  });

  final MessagesTab current;
  final int requestsBadge;
  final int chatsBadge;
  final ValueChanged<MessagesTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Tab(
              label: 'Requests',
              icon: MessagesAssets.tabCar,
              badge: requestsBadge,
              active: current == MessagesTab.requests,
              onTap: () => onSelected(MessagesTab.requests),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _Tab(
              label: 'Chats',
              icon: MessagesAssets.tabChat,
              badge: chatsBadge,
              active: current == MessagesTab.chats,
              onTap: () => onSelected(MessagesTab.chats),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.icon,
    required this.badge,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String icon;
  final int badge;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: active,
      button: true,
      label: badge > 0 ? '$label, $badge' : label,
      excludeSemantics: true,
      child: Material(
        color: active ? AppColors.ink : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: active ? null : onTap,
          child: SizedBox(
            height: 52,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(
                      icon,
                      size: 20,
                      color: active ? AppColors.lime : AppColors.ink,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: MessagesStyles.tab.copyWith(
                        color: active
                            ? AppColors.textOnDark
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (badge > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        constraints: const BoxConstraints(minWidth: 26),
                        height: 26,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.lime,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          style: MessagesStyles.labelM,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// F24 thread row.
class ChatListTile extends StatelessWidget {
  const ChatListTile({super.key, required this.chat, required this.onTap});

  final RideChat chat;
  final VoidCallback onTap;

  String get _statusLine => switch (chat.status) {
    RideRequestStatus.open =>
      chat.iAmDriver ? 'Ride request' : 'Your ride request',
    RideRequestStatus.confirmed => 'Ride booked',
    RideRequestStatus.inProgress => 'On the way',
    RideRequestStatus.completed => 'Ride done',
    RideRequestStatus.cancelled => 'Cancelled',
    RideRequestStatus.expired || RideRequestStatus.missed => 'Ride ended',
  };

  @override
  Widget build(BuildContext context) {
    final unread = chat.hasUnread;
    final preview = chat.lastMessage ?? 'No messages yet';
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(MessagesStyles.radiusThread),
      child: InkWell(
        borderRadius: BorderRadius.circular(MessagesStyles.radiusThread),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Row(
            children: [
              MessagesAvatar(
                initials: chat.other.initials,
                photoUrl: chat.other.photoUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            chat.other.shortName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MessagesStyles.labelL,
                          ),
                        ),
                        if (chat.lastAt != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            MessagesFormat.listTime(chat.lastAt!),
                            style: MessagesStyles.labelS,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: unread
                          ? MessagesStyles.labelM
                          : MessagesStyles.labelS,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _statusLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MessagesStyles.labelS,
                    ),
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 8),
                Semantics(
                  label: '${chat.unread} unread',
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.lime,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Kid photo stack at the right of a request card.
class _KidAvatars extends StatelessWidget {
  const _KidAvatars({required this.request});

  final RideRequest request;

  @override
  Widget build(BuildContext context) {
    final kids = request.kids.take(3).toList();
    if (kids.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 32,
      width: 32.0 + (kids.length - 1) * 20,
      child: Stack(
        children: [
          for (var i = 0; i < kids.length; i++)
            Positioned(
              left: i * 20.0,
              child: MessagesAvatar(
                initials: kids[i].initial,
                photoUrl: kids[i].photoUrl,
                size: 32,
                background: AppColors.limeTint,
                border: AppColors.surface,
              ),
            ),
        ],
      ),
    );
  }
}

/// F24a "Sarah needs a ride" — a request sent to the user as Ride Partner.
class IncomingRequestCard extends StatelessWidget {
  const IncomingRequestCard({
    super.key,
    required this.request,
    required this.busy,
    required this.onOpen,
    required this.onHelp,
    required this.onPass,
    required this.onWithdraw,
  });

  final RideRequest request;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onHelp;
  final VoidCallback onPass;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final parent = request.parent;
    final name = parent?.firstName ?? 'A parent';
    final meta = [
      MessagesFormat.names(request.kidNames, fallback: 'Kids'),
      if (request.distanceMiles != null)
        MessagesFormat.miles(request.distanceMiles!),
    ].join(' · ');
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(MessagesStyles.radiusRequest),
      child: InkWell(
        borderRadius: BorderRadius.circular(MessagesStyles.radiusRequest),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  MessagesAvatar(
                    initials: parent?.initials ?? '?',
                    photoUrl: parent?.photoUrl,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$name needs a ride',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MessagesStyles.tab,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MessagesStyles.meta,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _KidAvatars(request: request),
                ],
              ),
              const SizedBox(height: 10),
              MessagesIconLine(
                icon: MessagesAssets.school,
                text: '${request.pickupLabel} → ${request.destinationName}',
              ),
              const SizedBox(height: 10),
              MessagesIconLine(
                icon: MessagesAssets.clock,
                text: MessagesFormat.dayAndTime(request.pickupAt),
              ),
              if (request.youAreBusy) ...[
                const SizedBox(height: 10),
                Text(
                  'You have another ride around then.',
                  style: MessagesStyles.labelS,
                ),
              ],
              const SizedBox(height: 10),
              if (request.offered)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Offer sent · waiting for $name',
                        style: MessagesStyles.labelM,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 130,
                      child: MessagesPillButton(
                        label: 'Withdraw',
                        isLoading: busy,
                        onPressed: onWithdraw,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: MessagesPillButton(
                        label: 'I can help',
                        dark: true,
                        isLoading: busy,
                        onPressed: onHelp,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MessagesPillButton(
                        label: 'Not this time',
                        onPressed: busy ? null : onPass,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// F24a — the user's own open request with the offers on it (lime-soft
/// card like "New parents want to chat").
class MyRequestCard extends StatelessWidget {
  const MyRequestCard({
    super.key,
    required this.request,
    required this.busyId,
    required this.onOpen,
    required this.onOpenOffer,
    required this.onRespond,
  });

  final RideRequest request;
  final String? busyId;
  final VoidCallback onOpen;
  final ValueChanged<RideOffer> onOpenOffer;
  final void Function(RideOffer offer, bool approve) onRespond;

  @override
  Widget build(BuildContext context) {
    final kids = MessagesFormat.names(request.kidNames, fallback: 'your kids');
    final hasOffers = request.offers.isNotEmpty;
    return Material(
      color: hasOffers ? MessagesStyles.limeSoft : AppColors.surface,
      borderRadius: BorderRadius.circular(MessagesStyles.radiusRequest),
      child: InkWell(
        borderRadius: BorderRadius.circular(MessagesStyles.radiusRequest),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _KidAvatars(request: request),
                  if (request.kids.isNotEmpty) const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ride for $kids',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MessagesStyles.tab,
                        ),
                        Text(
                          hasOffers
                              ? '${request.offers.length} '
                                    '${request.offers.length == 1 ? 'offer' : 'offers'}'
                                    ' to answer'
                              : 'Waiting for a Ride Partner',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MessagesStyles.meta,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              MessagesIconLine(
                icon: MessagesAssets.school,
                text: '${request.pickupLabel} → ${request.destinationName}',
              ),
              const SizedBox(height: 10),
              MessagesIconLine(
                icon: MessagesAssets.clock,
                text: MessagesFormat.dayAndTime(request.pickupAt),
              ),
              for (final offer in request.offers) ...[
                const SizedBox(height: 12),
                OfferRow(
                  offer: offer,
                  busy: busyId == offer.offerId,
                  onOpen: () => onOpenOffer(offer),
                  onApprove: () => onRespond(offer, true),
                  onDecline: () => onRespond(offer, false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A Ride Partner's offer with Approve / Decline.
class OfferRow extends StatelessWidget {
  const OfferRow({
    super.key,
    required this.offer,
    required this.busy,
    required this.onOpen,
    required this.onApprove,
    required this.onDecline,
  });

  final RideOffer offer;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final p = offer.partner;
    final meta = [
      if (p.kidsAtSchool.isNotEmpty) MessagesFormat.names(p.kidsAtSchool),
      if (p.distanceMiles != null) MessagesFormat.miles(p.distanceMiles!),
      if (p.ridesGiven > 0) '${p.ridesGiven} rides given',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              MessagesAvatar(
                initials: p.initials,
                photoUrl: p.photoUrl,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${p.shortName} can drive',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MessagesStyles.tab,
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MessagesStyles.meta,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const AppIcon(MessagesAssets.tabChat, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: MessagesPillButton(
                label: 'Approve',
                dark: true,
                isLoading: busy,
                onPressed: onApprove,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MessagesPillButton(
                label: 'Decline',
                onPressed: busy ? null : onDecline,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "ⓘ Requests stay here until you answer."
class MessagesFootnote extends StatelessWidget {
  const MessagesFootnote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 20),
      child: Row(
        children: [
          const AppIcon(MessagesAssets.info, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: MessagesStyles.hint)),
        ],
      ),
    );
  }
}

/// Inline empty / error text for a tab.
class MessagesTabMessage extends StatelessWidget {
  const MessagesTabMessage({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
      child: Column(
        children: [
          Text(title, textAlign: TextAlign.center, style: AppTextStyles.title),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: AppTextStyles.body),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: 160,
              child: MessagesPillButton(
                label: 'Try again',
                dark: true,
                onPressed: onRetry,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
