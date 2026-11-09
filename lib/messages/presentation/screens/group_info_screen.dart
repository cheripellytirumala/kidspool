import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../../common/presentation/widgets/app_toggle.dart';
import '../../core/constants/messages_api_constants.dart';
import '../../core/constants/messages_assets.dart';
import '../../core/constants/messages_styles.dart';
import '../../domain/entities/ride_group.dart';
import '../providers/group_info_provider.dart';
import '../widgets/group_chat_widgets.dart';
import '../widgets/group_info_widgets.dart';
import '../widgets/group_name_dialog.dart';
import '../widgets/messages_common.dart';

/// A ride group's info: name, school, members and the group actions (Add
/// parents, Rename, Mute notifications, Leave group). Reads
/// [GroupChatArgs]; pops with `true` after the user leaves the group.
class GroupInfoScreen extends StatelessWidget {
  const GroupInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.settingsOf(context)?.arguments;
    return ChangeNotifierProvider<GroupInfoProvider>(
      create: (_) =>
          sl<GroupInfoProvider>()..open(args is GroupChatArgs ? args : null),
      child: const _GroupInfoView(),
    );
  }
}

class _GroupInfoView extends StatelessWidget {
  const _GroupInfoView();

  static String _fullMessage(RideGroupDetails group) =>
      'Groups can have up to ${group.maxMembers} families';

  Future<void> _addParents(BuildContext context) async {
    final provider = context.read<GroupInfoProvider>();
    final group = provider.group;
    if (group == null) return;
    if (group.isFull) {
      showAppSnack(context, '${_fullMessage(group)}.');
      return;
    }
    final ids = await AddParentsSheet.show(context, provider: provider);
    if (ids == null || ids.isEmpty || !context.mounted) return;
    final (added, error) = await provider.addMembers(ids);
    if (!context.mounted) return;
    showAppSnack(
      context,
      error ?? (added == 1 ? '1 parent added.' : '$added parents added.'),
    );
  }

  Future<void> _rename(BuildContext context, RideGroupDetails group) async {
    final provider = context.read<GroupInfoProvider>();
    final name = await showGroupNameDialog(
      context,
      title: 'Rename group',
      confirm: 'Save',
      initial: group.name,
    );
    if (name == null || name == group.name || !context.mounted) return;
    final error = await provider.rename(name);
    if (!context.mounted) return;
    showAppSnack(context, error ?? 'Group renamed.');
  }

  Future<void> _setMuted(BuildContext context, bool muted) async {
    final error = await context.read<GroupInfoProvider>().setMuted(muted);
    if (error != null && context.mounted) showAppSnack(context, error);
  }

  Future<void> _leave(BuildContext context, RideGroupDetails group) async {
    final provider = context.read<GroupInfoProvider>();
    final ok = await confirmMessagesAction(
      context,
      title: 'Leave ${group.name}?',
      message:
          'You’ll stop getting this group’s messages. A member can add you '
          'back later.',
      confirm: 'Leave group',
    );
    if (!ok || !context.mounted) return;
    final error = await provider.leave();
    if (!context.mounted) return;
    if (error != null) {
      showAppSnack(context, error);
      return;
    }
    showAppSnack(context, 'You left ${group.name}.');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupInfoProvider>();
    final group = provider.group;
    if (group == null) {
      if (provider.status.isFailure) {
        final missing =
            provider.errorMessage == MessagesApiConstants.groupsMissingMessage;
        return MessagesStateScreen(
          title: provider.hasGroup && !missing
              ? 'We couldn’t load this group'
              : 'Ride groups',
          message: provider.errorMessage ?? 'Please try again.',
          onRetry: provider.hasGroup && !missing ? provider.load : null,
        );
      }
      return const MessagesLoadingScreen();
    }
    final meta = [
      ?group.schoolName,
      RideGroupDetails.membersText(group.memberCount),
    ].join(' · ');
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
                  child: MessagesBackButton(size: 44),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.ink,
                  onRefresh: provider.load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                    children: [
                      const Center(child: GroupAvatar(size: 80)),
                      const SizedBox(height: 12),
                      Text(
                        group.name,
                        textAlign: TextAlign.center,
                        style: MessagesStyles.heading,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        meta,
                        textAlign: TextAlign.center,
                        style: MessagesStyles.groupMeta,
                      ),
                      const SizedBox(height: 16),
                      GroupActionRow(
                        icon: const AppIcon(AppAssets.iconPlus, size: 22),
                        title: 'Add parents',
                        subtitle: group.isFull
                            ? _fullMessage(group)
                            : 'Parents from your kids’ schools',
                        enabled: !group.isFull,
                        onTap: () => _addParents(context),
                      ),
                      const SizedBox(height: 12),
                      GroupActionRow(
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 22,
                          color: AppColors.ink,
                        ),
                        title: 'Rename',
                        onTap: () => _rename(context, group),
                      ),
                      const SizedBox(height: 12),
                      GroupActionRow(
                        icon: const Icon(
                          Icons.notifications_off_outlined,
                          size: 22,
                          color: AppColors.ink,
                        ),
                        title: 'Mute notifications',
                        trailing: AppToggle(
                          value: group.muted,
                          onChanged: (v) => _setMuted(context, v),
                        ),
                        onTap: () => _setMuted(context, !group.muted),
                      ),
                      const SizedBox(height: 18),
                      MessagesSectionLabel('Members · ${group.memberCount}'),
                      for (final m in group.members) ...[
                        const SizedBox(height: 12),
                        GroupMemberTile(member: m),
                      ],
                      const SizedBox(height: 12),
                      Center(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => _leave(context, group),
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
                                Text(
                                  'Leave group',
                                  style: MessagesStyles.labelL.copyWith(
                                    color: MessagesStyles.sos,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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
