import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../core/constants/messages_api_constants.dart';
import '../../core/constants/messages_styles.dart';
import '../../core/utils/messages_format.dart';
import '../providers/group_chat_provider.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/group_chat_widgets.dart';
import '../widgets/messages_common.dart';

/// A ride group's chat. Reads [GroupChatArgs] from the route.
///
/// Pops with `true` when the user left the group from its info screen.
class GroupChatScreen extends StatelessWidget {
  const GroupChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.settingsOf(context)?.arguments;
    return ChangeNotifierProvider<GroupChatProvider>(
      create: (_) =>
          sl<GroupChatProvider>()..open(args is GroupChatArgs ? args : null),
      child: const _GroupChatView(),
    );
  }
}

class _GroupChatView extends StatefulWidget {
  const _GroupChatView();

  @override
  State<_GroupChatView> createState() => _GroupChatViewState();
}

class _GroupChatViewState extends State<_GroupChatView>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  late final GroupChatProvider _provider = context.read<GroupChatProvider>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _provider.startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _provider
        ..startPolling()
        ..refreshMessages();
    } else {
      _provider.stopPolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider.stopPolling();
    _controller.dispose();
    super.dispose();
  }

  /// Opens the group info; polling pauses while it covers the thread.
  Future<void> _openInfo() async {
    final args = _provider.args;
    if (args == null) return;
    _provider.stopPolling();
    final left = await Navigator.of(context).pushNamed(
      AppRoutes.groupInfo,
      arguments: GroupChatArgs(groupId: args.groupId, name: _provider.title),
    );
    if (!mounted) return;
    if (left == true) {
      Navigator.of(context).pop(true);
      return;
    }
    _provider.startPolling();
    await Future.wait([_provider.loadGroup(), _provider.refreshMessages()]);
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    final error = await _provider.send(text);
    if (!mounted) return;
    if (error == null) {
      _controller.clear();
    } else {
      showAppSnack(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupChatProvider>();
    if (!provider.hasGroup) {
      return const MessagesStateScreen(
        title: 'No group to show',
        message: 'We couldn’t find this group. Open it from Messages.',
      );
    }
    if (provider.unavailable) {
      return const MessagesStateScreen(
        title: 'Ride groups',
        message: MessagesApiConstants.groupsMissingMessage,
      );
    }
    if (provider.group == null && provider.groupStatus.isFailure) {
      return MessagesStateScreen(
        title: 'We couldn’t open this group',
        message: provider.groupError ?? 'Please try again.',
        onRetry: provider.loadGroup,
      );
    }
    final items = _items(provider);
    return Scaffold(
      backgroundColor: AppColors.screen,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            GroupChatHeader(
              title: provider.title,
              subtitle: provider.subtitle,
              onInfo: _openInfo,
            ),
            Expanded(
              child: ColoredBox(
                color: MessagesStyles.threadBackground,
                child: ListView.separated(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  // Reversed so the newest message sits above the composer.
                  itemBuilder: (_, i) => items[items.length - 1 - i],
                ),
              ),
            ),
            ChatComposer(
              controller: _controller,
              enabled: true,
              sending: provider.sending,
              onSend: _send,
              onAddRide: null,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _items(GroupChatProvider provider) {
    final items = <Widget>[const SafetyTip()];
    if (provider.messagesStatus.isLoading && provider.messages.isEmpty) {
      items.add(const Center(child: AppLoader(size: 48)));
    }
    if (provider.messagesStatus.isFailure) {
      items.add(
        Center(
          child: TextButton(
            onPressed: provider.refreshMessages,
            child: Text(
              '${provider.messagesError ?? 'We couldn’t load the messages.'}'
              ' Tap to retry.',
              textAlign: TextAlign.center,
              style: MessagesStyles.labelS,
            ),
          ),
        ),
      );
    }
    DateTime? lastDay;
    for (final m in provider.messages) {
      if (lastDay == null || !MessagesFormat.sameDay(lastDay, m.createdAt)) {
        items.add(ChatPill(MessagesFormat.dayLabel(m.createdAt)));
        lastDay = m.createdAt;
      }
      items.add(GroupMessageView(message: m, mine: provider.isMine(m)));
    }
    if (provider.messagesStatus.isSuccess &&
        !provider.messages.any((m) => !m.isSystem)) {
      items.add(const ChatPill('Say hi to the group', system: true));
    }
    return items;
  }
}
