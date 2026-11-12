import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../ask_ride/presentation/screens/ask_ride_details_screen.dart'
    show AskRideArgs;
import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../core/constants/messages_api_constants.dart';
import '../../core/constants/messages_styles.dart';
import '../../core/utils/messages_format.dart';
import '../../domain/usecases/leave_ride_group.dart';
import '../providers/group_chat_provider.dart';
import '../widgets/chat_widgets.dart';
import '../../domain/entities/ride_ask.dart';
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

  /// "+ Ride": shares one of the user's open ride requests in the group;
  /// with none, opens Ask for a ride and offers to share the new one.
  Future<void> _addRide() async {
    if (_busyAddingRide) return;
    _busyAddingRide = true;
    try {
      final rides = await _provider.myOpenRides();
      if (!mounted) return;
      if (rides.isEmpty) return _askForRide();
      const shown = 6;
      final picked = await showChatActionsSheet(context, [
        for (final r in rides.take(shown))
          ChatAction(
            label: 'Share: ${GroupChatProvider.rideSummary(r)}',
            icon: Icons.directions_car_rounded,
          ),
        const ChatAction(label: 'Ask for a new ride', icon: Icons.add_rounded),
      ]);
      if (!mounted || picked == null) return;
      final count = rides.length < shown ? rides.length : shown;
      if (picked == count) return _askForRide();
      final error = await _provider.shareRide(rides[picked]);
      if (!mounted) return;
      showAppSnack(context, error ?? 'Ride shared with the group.');
    } finally {
      _busyAddingRide = false;
    }
  }

  bool _busyAddingRide = false;

  /// "I can help" on a ride card (first come, first served).
  Future<void> _help(GroupChatProvider provider, RideAsk ask) async {
    final (:error, :taken) = await provider.help(ask);
    if (!mounted) return;
    if (taken) {
      // The card was stale: another parent got there first.
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('This ride is already taken'),
          content: const Text(
            'Another parent offered to drive it first. Thanks for helping!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    showAppSnack(
      context,
      error ??
          'You’re driving this ride. We’ll remind you 30 min before — '
              'start it from Rides.',
    );
  }

  /// Ask for a ride, then back here with it posted as a card: the request
  /// is created when a driver taps "I can help".
  Future<void> _askForRide() async {
    final groupId = _provider.groupId;
    if (groupId == null) return;
    _provider.stopPolling();
    final posted = await Navigator.of(
      context,
    ).pushNamed(AppRoutes.askRide, arguments: AskRideArgs(groupId: groupId));
    if (!mounted) return;
    _provider.startPolling();
    await _provider.refreshMessages();
    if (posted == true && mounted) {
      showAppSnack(context, 'Ride posted. A parent can tap “I can help”.');
    }
  }

  /// ⋮: group info, or leave the group.
  Future<void> _more() async {
    final picked = await showChatActionsSheet(context, const [
      ChatAction(label: 'Group info', icon: Icons.info_outline_rounded),
      ChatAction(
        label: 'Leave group',
        icon: Icons.logout_rounded,
        destructive: true,
      ),
    ]);
    if (!mounted || picked == null) return;
    if (picked == 0) return _openInfo();
    await _leave();
  }

  /// Leaves the group on the server: its messages stop and it disappears
  /// from Messages, Profile and Home.
  Future<void> _leave() async {
    final args = _provider.args;
    if (args == null) return;
    final name = _provider.title;
    final ok = await confirmMessagesAction(
      context,
      title: 'Leave $name?',
      message:
          'You’ll stop getting this group’s messages. A member can add you '
          'back later.',
      confirm: 'Leave group',
    );
    if (!ok || !mounted) return;
    _provider.stopPolling();
    final result = await sl<LeaveRideGroup>()(args.groupId);
    if (!mounted) return;
    final error = result.getLeft().toNullable()?.message;
    if (error != null) {
      _provider.startPolling();
      return showAppSnack(context, error);
    }
    showAppSnack(context, 'You left $name.');
    Navigator.of(context).pop(true);
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
              onMore: _more,
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
            // Way out for members, right above the message box. The admin
            // doesn't get it (shown once the members are loaded).
            if (provider.group case final group? when !group.iAmOwner)
              LeaveGroupBar(onLeave: _leave),
            ChatComposer(
              controller: _controller,
              enabled: true,
              sending: provider.sending,
              onSend: _send,
              onAddRide: _addRide,
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
      // Someone else took this ride: it's gone for everyone else.
      if (provider.isHidden(m)) continue;
      if (lastDay == null || !MessagesFormat.sameDay(lastDay, m.createdAt)) {
        items.add(ChatPill(MessagesFormat.dayLabel(m.createdAt)));
        lastDay = m.createdAt;
      }
      final mine = provider.isMine(m);
      final ask = provider.askFor(m);
      items.add(
        ask == null
            ? GroupMessageView(message: m, mine: mine)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GroupMessageView(message: m, mine: mine),
                  RideAskFooter(
                    ask: ask,
                    mine: mine,
                    busy: provider.helpingId == ask.id,
                    onHelp: () => _help(provider, ask),
                    onTrack: ask.requestIds.isEmpty
                        ? null
                        : () => Navigator.of(context).pushNamed(
                            AppRoutes.liveTracking,
                            arguments: RideArgs(ask.requestIds.first),
                          ),
                  ),
                ],
              ),
      );
    }
    if (provider.messagesStatus.isSuccess &&
        !provider.messages.any((m) => !m.isSystem)) {
      items.add(const ChatPill('Say hi to the group', system: true));
    }
    return items;
  }
}
