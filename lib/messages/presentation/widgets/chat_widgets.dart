import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../core/constants/messages_api_constants.dart';
import '../../core/constants/messages_assets.dart';
import '../../core/constants/messages_styles.dart';
import '../../core/utils/messages_format.dart';
import '../../domain/entities/chat_person.dart';
import '../../domain/entities/ride_chat.dart';
import '../../domain/entities/ride_request.dart';
import 'messages_common.dart';

/// F19 chat header: back, avatar, name and `Home · Lincoln`.
class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.person,
    required this.subtitle,
    required this.onInfo,
  });

  final ChatPerson person;
  final String? subtitle;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 16, 10),
      child: Row(
        children: [
          const MessagesBackButton(size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              button: true,
              label: 'Ride info',
              child: InkWell(
                onTap: onInfo,
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  children: [
                    MessagesAvatar(
                      initials: person.initials,
                      photoUrl: person.photoUrl,
                      size: 40,
                      background: AppColors.surface,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.shortName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MessagesStyles.labelL,
                          ),
                          if (subtitle != null)
                            Row(
                              children: [
                                const AppIcon(
                                  MessagesAssets.school12,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: MessagesStyles.labelS,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lime-soft "Keep chats in KidPool…" tip.
class SafetyTip extends StatelessWidget {
  const SafetyTip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: MessagesStyles.limeSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const AppIcon(MessagesAssets.shield, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Keep chats in KidPool. Addresses are shared only after a ride '
              'is booked.',
              style: MessagesStyles.labelS.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered pill: day separator (white) or system line (surface-strong).
class ChatPill extends StatelessWidget {
  const ChatPill(this.text, {super.key, this.system = false});

  final String text;
  final bool system;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: system ? 6 : 5),
        decoration: BoxDecoration(
          color: system ? AppColors.surfaceStrong : AppColors.screen,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: MessagesStyles.labelM.copyWith(
            color: system ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// One message. Own messages: lime, right, no avatar. Others: white with the
/// sender's name and avatar.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.sender,
  });

  final ChatMessage message;
  final bool mine;
  final ChatPerson sender;

  @override
  Widget build(BuildContext context) {
    const big = Radius.circular(MessagesStyles.radiusBubble);
    const tail = Radius.circular(MessagesStyles.radiusBubbleTail);
    final bubble = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: MessagesStyles.bubbleWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? AppColors.lime : AppColors.screen,
          borderRadius: BorderRadius.only(
            topLeft: big,
            topRight: big,
            bottomLeft: mine ? big : tail,
            bottomRight: mine ? tail : big,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine) ...[
              Text(
                sender.firstName,
                style: MessagesStyles.labelM.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
            ],
            Text(message.body, style: MessagesStyles.bubble),
            const SizedBox(height: 3),
            Text(
              MessagesFormat.clock(message.createdAt),
              style: MessagesStyles.labelS,
            ),
          ],
        ),
      ),
    );
    return Semantics(
      label: '${mine ? 'You' : sender.firstName}: ${message.body}',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            MessagesAvatar(
              initials: sender.initials,
              photoUrl: sender.photoUrl,
              size: 34,
              background: AppColors.surfaceStrong,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

/// Actions on the in-chat ride card.
class RideCardActions {
  const RideCardActions({
    this.primary,
    this.onPrimary,
    this.secondary,
    this.onSecondary,
  });

  final String? primary;
  final VoidCallback? onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;

  bool get isEmpty => primary == null && secondary == null;
}

/// F19 "Ride request card" — white, 2px ink border, the ride's kids, route,
/// time and state, with the actions that fit who's looking.
class RideRequestChatCard extends StatelessWidget {
  const RideRequestChatCard({
    super.key,
    required this.ride,
    required this.statusLine,
    required this.actions,
    required this.busy,
    this.onTap,
  });

  final RideRequest ride;
  final String statusLine;
  final RideCardActions actions;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final kid = ride.kids.isEmpty ? null : ride.kids.first;
    final kids = MessagesFormat.names(ride.kidNames, fallback: 'Kids');
    final when = [
      MessagesFormat.dayAndTime(ride.pickupAt),
      if (ride.repeats) '${ride.openDaysInSeries} days',
    ].join(' · ');
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: MessagesStyles.rideCardWidth,
        ),
        child: Material(
          color: AppColors.screen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: AppColors.ink, width: 2),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.lime,
                          shape: BoxShape.circle,
                        ),
                        child: const AppIcon(MessagesAssets.car15, size: 15),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ride request',
                          style: MessagesStyles.labelL,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      MessagesAvatar(
                        initials: kid?.initial ?? '?',
                        photoUrl: kid?.photoUrl,
                        size: 28,
                        background: AppColors.limeTint,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$kids · ${ride.pickupLabel} → '
                          '${ride.destinationName}',
                          style: MessagesStyles.labelM,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const AppIcon(MessagesAssets.repeat14, size: 14),
                      const SizedBox(width: 6),
                      Expanded(child: Text(when, style: MessagesStyles.labelS)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const AppIcon(MessagesAssets.check, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          statusLine,
                          style: MessagesStyles.labelS.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!actions.isEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (actions.primary != null)
                          Expanded(
                            child: MessagesPillButton(
                              label: actions.primary!,
                              dark: true,
                              height: 44,
                              isLoading: busy,
                              onPressed: actions.onPrimary,
                            ),
                          ),
                        if (actions.primary != null &&
                            actions.secondary != null)
                          const SizedBox(width: 8),
                        if (actions.secondary != null)
                          Expanded(
                            child: MessagesPillButton(
                              label: actions.secondary!,
                              background: AppColors.surface,
                              height: 44,
                              onPressed: busy ? null : actions.onSecondary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// F19 composer: "+ Ride", message field, lime send button. Disabled with
/// [MessagesApiConstants.chatMissingMessage] while the chat SQL isn't on the
/// server.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.onSend,
    required this.onAddRide,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onAddRide;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.screen,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: 'Ask for a ride',
                excludeSemantics: true,
                child: Material(
                  color: AppColors.ink,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: onAddRide,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppIcon(MessagesAssets.plus16, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Ride',
                            style: MessagesStyles.labelM.copyWith(
                              color: AppColors.textOnDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: MessagesApiConstants.maxMessageLength,
                    textCapitalization: TextCapitalization.sentences,
                    style: MessagesStyles.labelM,
                    cursorColor: AppColors.ink,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      counterText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: enabled
                          ? 'Message'
                          : MessagesApiConstants.chatMissingMessage,
                      hintMaxLines: 2,
                      hintStyle: MessagesStyles.labelM.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                enabled: enabled,
                label: 'Send',
                excludeSemantics: true,
                child: Opacity(
                  opacity: enabled ? 1 : 0.4,
                  child: Material(
                    color: AppColors.lime,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: enabled && !sending ? onSend : null,
                      child: SizedBox.square(
                        dimension: 42,
                        child: Center(
                          child: sending
                              ? const AppLoader.glyph(size: 18)
                              : const AppIcon(MessagesAssets.send, size: 20),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
