import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/messages_assets.dart';
import '../../core/constants/messages_styles.dart';
import '../../core/utils/messages_format.dart';
import '../../domain/entities/chat_person.dart';
import '../../domain/entities/ride_chat.dart';
import '../../domain/entities/ride_ask.dart';
import '../../domain/entities/ride_group.dart';
import 'chat_widgets.dart';
import 'messages_common.dart';

/// Lime circle with the people icon: a ride group's avatar.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.lime,
        shape: BoxShape.circle,
      ),
      child: AppIcon(MessagesAssets.people, size: size / 2),
    );
  }
}

/// Group chat header: back, group avatar, name and "6 members", plus an
/// info button. Tapping the name or the button opens the group info.
class GroupChatHeader extends StatelessWidget {
  const GroupChatHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onInfo,
    this.onMore,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onInfo;

  /// ⋮ "More" (leave group…); hidden when null.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Row(
        children: [
          const MessagesBackButton(size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              button: onInfo != null,
              label: 'Group info',
              child: InkWell(
                onTap: onInfo,
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  children: [
                    const GroupAvatar(size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MessagesStyles.labelL,
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MessagesStyles.labelS,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onInfo != null) ...[
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Group details',
              excludeSemantics: true,
              child: Material(
                color: AppColors.surface,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onInfo,
                  child: const SizedBox.square(
                    dimension: 44,
                    child: Center(
                      child: AppIcon(MessagesAssets.info, size: 20),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (onMore != null) ...[
            const SizedBox(width: 8),
            ChatMoreButton(onPressed: onMore!),
          ],
        ],
      ),
    );
  }
}

/// A system line in a group chat ("Ava joined"): centered grey caption.
class GroupSystemLine extends StatelessWidget {
  const GroupSystemLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: MessagesStyles.labelS,
      ),
    );
  }
}

/// A group message: a system caption, or a [ChatBubble] with the sender's
/// first name and initials for other people's messages.
class GroupMessageView extends StatelessWidget {
  const GroupMessageView({
    super.key,
    required this.message,
    required this.mine,
  });

  final GroupMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final sender = message.sender;
    if (message.isSystem || sender == null) {
      return GroupSystemLine(message.body);
    }
    return ChatBubble(
      message: ChatMessage(
        id: message.id,
        senderId: sender.id,
        body: message.body,
        createdAt: message.createdAt,
      ),
      mine: mine,
      sender: ChatPerson(
        id: sender.id,
        firstName: sender.firstName,
        initials: sender.initials,
      ),
    );
  }
}

/// F24 row for a ride group: avatar with the member count, name, last
/// message, time, muted icon and unread dot.
class GroupListTile extends StatelessWidget {
  const GroupListTile({super.key, required this.group, required this.onTap});

  final RideGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = group.hasUnread;
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
              _CountedAvatar(count: group.memberCount),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // The name takes all the width the time leaves.
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  group.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: MessagesStyles.labelL,
                                ),
                              ),
                              if (group.muted) ...[
                                const SizedBox(width: 4),
                                Semantics(
                                  label: 'Muted',
                                  child: const Icon(
                                    Icons.notifications_off_outlined,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (group.lastAt != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            MessagesFormat.listTime(group.lastAt!),
                            style: MessagesStyles.labelS,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      group.lastMessage ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: unread
                          ? MessagesStyles.labelM
                          : MessagesStyles.labelS,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Group · ${group.membersLabel}',
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
                  label: '${group.unread} unread',
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

/// Group avatar with a small ink member-count badge.
class _CountedAvatar extends StatelessWidget {
  const _CountedAvatar({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const GroupAvatar(),
          if (count > 0)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: Text(
                  '$count',
                  style: MessagesStyles.labelS.copyWith(
                    color: AppColors.textOnDark,
                    fontSize: 10,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Thin bar above the group's message box: "Not interested? Leave group".
class LeaveGroupBar extends StatelessWidget {
  const LeaveGroupBar({super.key, required this.onLeave});

  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.screen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Not interested in this group?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MessagesStyles.labelS,
              ),
            ),
            TextButton.icon(
              onPressed: onLeave,
              style: TextButton.styleFrom(
                foregroundColor: MessagesStyles.sos,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(44, 40),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(
                'Leave group',
                style: MessagesStyles.labelM.copyWith(
                  color: MessagesStyles.sos,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Under a ride card in a group chat: "I can help" for drivers, or where
/// the ride stands. The request is only created when a driver taps it.
class RideAskFooter extends StatelessWidget {
  const RideAskFooter({
    super.key,
    required this.ask,
    required this.mine,
    required this.busy,
    required this.onHelp,
    this.onTrack,
  });

  /// Opens live tracking for the booked ride (the parent who asked).
  final VoidCallback? onTrack;

  final RideAsk ask;

  /// The card is on the right (the signed-in parent posted it).
  final bool mine;
  final bool busy;
  final VoidCallback onHelp;

  String? get _status => switch (ask.status) {
    RideAskStatus.taken when ask.rideStatus == 'completed' => 'Ride done ✅',
    RideAskStatus.taken when ask.isHelper && ask.rideStarted =>
      'You’re driving this ride · on the way',
    RideAskStatus.taken when ask.isHelper =>
      'You’re driving this ride · start it from Rides',
    RideAskStatus.taken when ask.isMine && ask.rideStarted =>
      '${ask.helperName ?? 'A parent'} started the ride',
    RideAskStatus.taken when ask.isMine =>
      '${ask.helperName ?? 'A parent'} is driving · booked',
    RideAskStatus.taken => '${ask.helperName ?? 'A parent'} is driving',
    RideAskStatus.cancelled => 'No longer needed',
    RideAskStatus.open when ask.isMine => 'Waiting for a parent to help',
    RideAskStatus.open => null,
  };

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Padding(
      padding: EdgeInsets.only(left: mine ? 0 : 56, top: 6),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ask.canHelp
            ? FilledButton.icon(
                onPressed: busy ? null : onHelp,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: AppColors.lime,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                icon: busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.volunteer_activism_rounded, size: 18),
                label: Text(
                  'I can help',
                  style: MessagesStyles.labelM.copyWith(color: AppColors.lime),
                ),
              )
            : status == null
            ? const SizedBox.shrink()
            // Track only once the driver has started the ride.
            : ask.isMine &&
                  ask.status == RideAskStatus.taken &&
                  ask.rideStarted &&
                  onTrack != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(status, style: MessagesStyles.labelS),
                  const SizedBox(height: 6),
                  FilledButton.icon(
                    onPressed: onTrack,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.lime,
                      foregroundColor: AppColors.ink,
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.map_rounded, size: 18),
                    label: Text('Track ride', style: MessagesStyles.labelM),
                  ),
                ],
              )
            : Text(status, style: MessagesStyles.labelS),
      ),
    );
  }
}
