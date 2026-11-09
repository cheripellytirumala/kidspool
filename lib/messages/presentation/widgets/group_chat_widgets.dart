import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/messages_assets.dart';
import '../../core/constants/messages_styles.dart';
import '../../core/utils/messages_format.dart';
import '../../domain/entities/chat_person.dart';
import '../../domain/entities/ride_chat.dart';
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
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onInfo;

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
                        const Spacer(),
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
