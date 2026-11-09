import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../providers/ride_groups_provider.dart';
import '../widgets/group_chat_widgets.dart';
import '../widgets/messages_common.dart';

/// "Your ride groups" (Home › Your ride group › See all): every group the
/// user is in; tapping one opens its chat.
class RideGroupsScreen extends StatelessWidget {
  const RideGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RideGroupsProvider>(
      create: (_) => sl<RideGroupsProvider>()..load(),
      child: const _RideGroupsView(),
    );
  }
}

class _RideGroupsView extends StatelessWidget {
  const _RideGroupsView();

  Future<void> _open(BuildContext context, String id, String name) async {
    final provider = context.read<RideGroupsProvider>();
    await Navigator.pushNamed(
      context,
      AppRoutes.groupChat,
      arguments: GroupChatArgs(groupId: id, name: name),
    );
    await provider.load();
  }

  Future<void> _startGroup(BuildContext context) async {
    final provider = context.read<RideGroupsProvider>();
    // Pick families there; "Start a group" appears once some are selected.
    await Navigator.pushNamed(context, AppRoutes.familiesNearYou);
    await provider.load();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RideGroupsProvider>();
    final groups = provider.groups;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.screen,
        body: AppLoadingOverlay(
          isLoading: provider.isFirstLoad,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: MessagesBackButton(),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: provider.load,
                    color: AppColors.ink,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        Text('Ride groups', style: AppTextStyles.displayL),
                        const SizedBox(height: 4),
                        Text(
                          groups.isEmpty
                              ? 'Families you plan rides with'
                              : groups.length == 1
                              ? 'You’re in 1 group'
                              : 'You’re in ${groups.length} groups',
                          style: AppTextStyles.body,
                        ),
                        const SizedBox(height: 16),
                        for (final group in groups) ...[
                          GroupListTile(
                            group: group,
                            onTap: () => _open(context, group.id, group.name),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (groups.isEmpty && !provider.isFirstLoad)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              provider.error ??
                                  'You’re not in any ride groups yet. Pick '
                                      'families near you and start one.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body,
                            ),
                          )
                        else if (provider.error != null)
                          Text(provider.error!, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                ),
                if (!provider.notSetUp)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: AppButton(
                      label: 'Start a group',
                      onPressed: () => _startGroup(context),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
