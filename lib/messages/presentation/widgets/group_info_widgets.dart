import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/presentation/state/view_state.dart';
import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../core/constants/messages_styles.dart';
import '../../core/utils/messages_format.dart';
import '../../domain/entities/ride_group.dart';
import '../providers/group_info_provider.dart';
import 'messages_common.dart';

/// A group member: initials avatar, first name ("You"), "Owner" pill and
/// kids' names.
class GroupMemberTile extends StatelessWidget {
  const GroupMemberTile({super.key, required this.member});

  final RideGroupMember member;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(MessagesStyles.radiusRow),
      ),
      child: Row(
        children: [
          MessagesAvatar(
            initials: member.isMe ? 'Me' : member.initials,
            size: 46,
            background: member.isMe ? AppColors.lime : AppColors.screen,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.isMe ? 'You' : member.firstName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MessagesStyles.labelL,
                ),
                Text(
                  member.kids.isEmpty
                      ? 'Parent'
                      : 'Parent of ${MessagesFormat.names(member.kids)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MessagesStyles.meta,
                ),
              ],
            ),
          ),
          if (member.isOwner) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Owner',
                style: MessagesStyles.labelS.copyWith(
                  color: AppColors.textOnDark,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A settings row on the group info screen (icon, title, subtitle, and a
/// trailing widget such as a toggle).
class GroupActionRow extends StatelessWidget {
  const GroupActionRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  final Widget icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(MessagesStyles.radiusRow);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: AppColors.surface,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                SizedBox.square(dimension: 24, child: Center(child: icon)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: MessagesStyles.labelL),
                      if (subtitle != null)
                        Text(subtitle!, style: MessagesStyles.meta),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Add parents" picker: the parents the user may add, with checkboxes,
/// limited to the group's free slots. Returns the picked ids, or null.
class AddParentsSheet extends StatefulWidget {
  const AddParentsSheet({super.key});

  static Future<List<String>?> show(
    BuildContext context, {
    required GroupInfoProvider provider,
  }) {
    provider.loadCandidates();
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.screen,
      barrierColor: const Color(0x8C0A0A0A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: const AddParentsSheet(),
      ),
    );
  }

  @override
  State<AddParentsSheet> createState() => _AddParentsSheetState();
}

class _AddParentsSheetState extends State<AddParentsSheet> {
  final Set<String> _picked = {};

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupInfoProvider>();
    final slots = provider.remainingSlots;
    final candidates = provider.candidates;
    final status = provider.candidatesStatus;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Add parents', style: AppTextStyles.headingH3),
              const SizedBox(height: 4),
              Text(
                slots == 1
                    ? 'You can add 1 more family.'
                    : 'You can add $slots more families.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 12),
              Flexible(child: _list(provider, candidates, status, slots)),
              const SizedBox(height: 12),
              AppButton(
                label: _picked.isEmpty
                    ? 'Add'
                    : 'Add ${_picked.length} '
                          '${_picked.length == 1 ? 'parent' : 'parents'}',
                variant: AppButtonVariant.dark,
                onPressed: _picked.isEmpty
                    ? null
                    : () => Navigator.pop(context, _picked.toList()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(
    GroupInfoProvider provider,
    List<RideGroupMember> candidates,
    ViewStatus status,
    int slots,
  ) {
    if (status.isLoading || status.isInitial) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: AppLoader(size: 48)),
      );
    }
    if (status.isFailure) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: MessagesStateView(
          title: 'We couldn’t load parents',
          message: provider.candidatesError ?? 'Please try again.',
          onRetry: provider.loadCandidates,
        ),
      );
    }
    if (candidates.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No more parents from your kids’ schools to add right now.',
          style: AppTextStyles.body,
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: candidates.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final c = candidates[i];
        final picked = _picked.contains(c.id);
        final canPick = picked || _picked.length < slots;
        return _CandidateRow(
          candidate: c,
          picked: picked,
          onTap: canPick
              ? () => setState(() {
                  if (!_picked.remove(c.id)) _picked.add(c.id);
                })
              : null,
        );
      },
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.candidate,
    required this.picked,
    required this.onTap,
  });

  final RideGroupMember candidate;
  final bool picked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(MessagesStyles.radiusRow);
    return MergeSemantics(
      child: Semantics(
        checked: picked,
        enabled: onTap != null,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: Material(
            color: AppColors.surface,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    MessagesAvatar(initials: candidate.initials, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            candidate.firstName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MessagesStyles.labelL,
                          ),
                          if (candidate.kids.isNotEmpty)
                            Text(
                              'Parent of '
                              '${MessagesFormat.names(candidate.kids)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MessagesStyles.meta,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ExcludeSemantics(child: _CheckBox(checked: picked)),
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

/// 22px square checkbox, as in `AppCheckboxRow`.
class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: checked ? AppColors.ink : AppColors.screen,
        borderRadius: BorderRadius.circular(7),
        border: checked
            ? null
            : Border.all(color: AppColors.borderField, width: 2),
      ),
      child: checked ? const AppIcon(AppAssets.iconCheckBox, size: 12) : null,
    );
  }
}
