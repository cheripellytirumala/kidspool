import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../../ride_tracking/presentation/widgets/ride_contact.dart';
import '../../core/constants/messages_assets.dart';
import '../../core/constants/messages_styles.dart';
import '../../core/utils/messages_format.dart';
import '../../domain/entities/ride_request.dart';
import '../providers/ride_group_info_provider.dart';
import '../widgets/messages_common.dart';

/// GC6 · Group info & members, for one ride chat. Reads [RideChatArgs].
class RideGroupInfoScreen extends StatelessWidget {
  const RideGroupInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.settingsOf(context)?.arguments;
    return ChangeNotifierProvider<RideGroupInfoProvider>(
      create: (_) =>
          sl<RideGroupInfoProvider>()..open(args is RideChatArgs ? args : null),
      child: const _GroupInfoView(),
    );
  }
}

class _GroupInfoView extends StatelessWidget {
  const _GroupInfoView();

  Future<void> _leave(BuildContext context, String label) async {
    final provider = context.read<RideGroupInfoProvider>();
    final ok = await confirmMessagesAction(
      context,
      title: '$label?',
      message: provider.iAmDriver
          ? 'The parent will be told so they can find someone else.'
          : 'Your Ride Partner will be told.',
      confirm: label,
    );
    if (!ok || !context.mounted) return;
    final error = await provider.leave();
    if (!context.mounted) return;
    showAppSnack(context, error ?? 'Done — everyone has been told.');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RideGroupInfoProvider>();
    final ride = provider.ride;
    if (ride == null) {
      if (provider.status.isFailure) {
        return MessagesStateScreen(
          title: provider.hasChat
              ? 'We couldn’t load this ride'
              : 'No ride to show',
          message: provider.errorMessage ?? 'Please try again.',
          onRetry: provider.hasChat ? provider.retry : null,
        );
      }
      return const MessagesLoadingScreen();
    }
    final members = provider.members;
    final leave = provider.leaveLabel;
    return Scaffold(
      backgroundColor: AppColors.screen,
      body: SafeArea(
        child: AppLoadingOverlay(
          isLoading: provider.busy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _BackPill(),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                  children: [
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.lime,
                          shape: BoxShape.circle,
                        ),
                        child: const AppIcon(MessagesAssets.people, size: 40),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      provider.title,
                      textAlign: TextAlign.center,
                      style: MessagesStyles.heading,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      provider.subtitle,
                      textAlign: TextAlign.center,
                      style: MessagesStyles.groupMeta,
                    ),
                    const SizedBox(height: 12),
                    _RideRow(ride: ride),
                    const SizedBox(height: 12),
                    // GC6: section label sits 6px under the row above.
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: MessagesSectionLabel(
                        'Members · ${members.length}',
                      ),
                    ),
                    for (final m in members) ...[
                      const SizedBox(height: 12),
                      _MemberTile(
                        member: m,
                        onChat: () => Navigator.of(context).maybePop(),
                        onCall: () => RideContact.call(
                          context,
                          name: m.person.firstName,
                          phone: m.person.phone,
                        ),
                      ),
                    ],
                    if (leave != null) ...[
                      // 12 gap + the 6px tap padding = Figma's 18.
                      const SizedBox(height: 12),
                      Center(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => _leave(context, leave),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const AppIcon(MessagesAssets.leave, size: 20),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    leave,
                                    style: MessagesStyles.labelL.copyWith(
                                      color: MessagesStyles.sos,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (provider.left) ...[
                      const SizedBox(height: 18),
                      Text(
                        'You left this ride.',
                        textAlign: TextAlign.center,
                        style: MessagesStyles.groupMeta,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// GC6 "Back" pill (chevron + Back).
class _BackPill extends StatelessWidget {
  const _BackPill();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => Navigator.of(context).maybePop(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon(MessagesAssets.chevronLeft, size: 22),
              const SizedBox(width: 6),
              Text('Back', style: MessagesStyles.tab),
            ],
          ),
        ),
      ),
    );
  }
}

/// The ride: route + time (where the Figma has the Notifications row).
class _RideRow extends StatelessWidget {
  const _RideRow({required this.ride});

  final RideRequest ride;

  @override
  Widget build(BuildContext context) {
    final when = [
      MessagesFormat.dayAndTime(ride.pickupAt),
      if (ride.repeats) '${ride.openDaysInSeries} days',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(MessagesStyles.radiusRow),
      ),
      child: Row(
        children: [
          const AppIcon(MessagesAssets.clock, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(when, style: MessagesStyles.labelL),
                Text(
                  [
                    MessagesFormat.names(ride.kidNames, fallback: 'Kids'),
                    ride.destinationName,
                  ].join(' · '),
                  style: MessagesStyles.meta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.onChat,
    required this.onCall,
  });

  final GroupMember member;
  final VoidCallback onChat;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final p = member.person;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(MessagesStyles.radiusRow),
      ),
      child: Row(
        children: [
          MessagesAvatar(
            initials: member.isYou ? 'Me' : p.initials,
            photoUrl: p.photoUrl,
            size: 46,
            background: member.isYou ? AppColors.lime : AppColors.screen,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.isYou ? 'You' : p.shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MessagesStyles.labelL,
                ),
                Text(
                  member.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MessagesStyles.meta,
                ),
              ],
            ),
          ),
          if (!member.isYou) ...[
            const SizedBox(width: 8),
            _RoundAction(
              icon: MessagesAssets.tabChat,
              label: 'Chat with ${p.firstName}',
              onTap: onChat,
            ),
            const SizedBox(width: 12),
            _RoundAction(
              icon: MessagesAssets.phone,
              label: 'Call ${p.firstName}',
              onTap: onCall,
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.screen,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 40,
            child: Center(child: AppIcon(icon, size: 20)),
          ),
        ),
      ),
    );
  }
}
