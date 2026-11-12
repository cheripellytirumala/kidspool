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
import '../../core/constants/messages_styles.dart';
import '../../core/utils/messages_format.dart';
import '../../data/data_sources/local/hidden_chats_store.dart';
import '../../domain/entities/ride_request.dart';
import '../../domain/usecases/pass_ride_request.dart';
import '../providers/ride_chat_provider.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/messages_common.dart';

/// F19 · Ride chat. Reads [RideChatArgs] from the route.
class RideChatScreen extends StatelessWidget {
  const RideChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.settingsOf(context)?.arguments;
    return ChangeNotifierProvider<RideChatProvider>(
      create: (_) =>
          sl<RideChatProvider>()..open(args is RideChatArgs ? args : null),
      child: const _ChatView(),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  late final RideChatProvider _provider = context.read<RideChatProvider>();

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

  /// Pauses polling while another screen covers the thread.
  Future<void> _push(String route, Object? arguments) async {
    _provider.stopPolling();
    await Navigator.of(context).pushNamed(route, arguments: arguments);
    if (!mounted) return;
    _provider.startPolling();
    await Future.wait([_provider.refreshMessages(), _provider.loadRide()]);
  }

  /// "+ Ride": Ask for a ride, then back here with the new ride posted in
  /// this conversation.
  Future<void> _addRide() async {
    _provider.stopPolling();
    final message = await Navigator.of(context).pushNamed(
      AppRoutes.askRide,
      arguments: const AskRideArgs(fromChat: true),
    );
    if (!mounted) return;
    _provider.startPolling();
    if (message is String) {
      final error = await _provider.send(message);
      if (!mounted) return;
      showAppSnack(context, error ?? 'Ride requested and shared here.');
    }
    await Future.wait([_provider.refreshMessages(), _provider.loadRide()]);
  }

  /// ⋮: ride info, or delete this chat from the user's Messages.
  Future<void> _more(RideChatProvider provider) async {
    final picked = await showChatActionsSheet(context, const [
      ChatAction(label: 'Ride info', icon: Icons.info_outline_rounded),
      ChatAction(
        label: 'Delete chat',
        icon: Icons.delete_outline_rounded,
        destructive: true,
      ),
    ]);
    if (!mounted || picked == null) return;
    if (picked == 0) return _push(AppRoutes.rideGroupInfo, provider.args);
    await _deleteChat(provider);
  }

  /// Hides this chat on this device (it comes back if they write again).
  /// A parent who was only asked to drive also passes on the request.
  Future<void> _deleteChat(RideChatProvider provider) async {
    final args = provider.args;
    if (args == null) return;
    final name = provider.other.firstName;
    final ok = await confirmMessagesAction(
      context,
      title: 'Delete this chat?',
      message:
          'It disappears from your Messages. If $name writes again, it '
          'comes back.',
      confirm: 'Delete chat',
    );
    if (!ok || !mounted) return;
    _provider.stopPolling();
    await sl<HiddenChatsStore>().hide(args.requestId, args.driverId);
    final ride = provider.ride;
    if (args.iAmDriver && ride != null && ride.isOpen && !ride.offered) {
      await sl<PassRideRequest>()(args.requestId);
    }
    if (!mounted) return;
    showAppSnack(context, 'Chat deleted.');
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

  Future<void> _act(Future<String?> Function() action, String done) async {
    final error = await action();
    if (!mounted) return;
    showAppSnack(context, error ?? done);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RideChatProvider>();
    if (!provider.hasChat) {
      return const MessagesStateScreen(
        title: 'No chat to show',
        message: 'We couldn’t find this chat. Open it from Messages.',
      );
    }
    final ride = provider.ride;
    final other = provider.other;
    final items = _items(provider);
    return Scaffold(
      backgroundColor: AppColors.screen,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ChatHeader(
              person: other,
              subtitle: ride == null
                  ? null
                  : '${ride.pickupLabel} · ${ride.destinationName}',
              onInfo: () => _push(AppRoutes.rideGroupInfo, provider.args),
              onMore: () => _more(provider),
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
              enabled: !provider.chatMissing,
              sending: provider.sending,
              onSend: _send,
              onAddRide: _addRide,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _items(RideChatProvider provider) {
    final ride = provider.ride;
    final other = provider.other;
    final items = <Widget>[const SafetyTip()];

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
      items.add(
        ChatBubble(message: m, mine: provider.isMine(m), sender: other),
      );
    }
    // F19: the ride card sits in the thread under the latest messages.
    if (ride != null) {
      final (status, actions) = _cardState(provider, ride);
      items.add(
        RideRequestChatCard(
          ride: ride,
          statusLine: status,
          actions: actions,
          busy: provider.busy,
          onTap: () => _push(AppRoutes.rideGroupInfo, provider.args),
        ),
      );
    } else if (provider.rideStatus.isFailure) {
      items.add(ChatPill(provider.rideError ?? 'We couldn’t load this ride.'));
    } else {
      items.add(const Center(child: AppLoader(size: 48)));
    }

    if (provider.messages.isEmpty &&
        provider.messagesStatus.isSuccess &&
        !provider.chatMissing) {
      items.add(ChatPill('Say hi to ${other.firstName}', system: true));
    }
    return items;
  }

  (String, RideCardActions) _cardState(RideChatProvider p, RideRequest ride) {
    final name = p.other.firstName;
    final booked = p.bookedHere;
    if (booked) {
      final done = ride.status == RideRequestStatus.completed;
      final who = p.iAmDriver ? 'You drive' : '$name drives';
      // The parent's live map opens once the driver starts the ride.
      if (!p.iAmDriver && ride.status == RideRequestStatus.confirmed) {
        return (
          '$who · booked · tracking starts when $name starts the ride',
          const RideCardActions(),
        );
      }
      return (
        '$who · ${done ? 'ride done' : 'booked'}',
        RideCardActions(
          primary: done ? 'See summary' : 'Open live ride',
          onPrimary: () => _push(
            done ? AppRoutes.rideCompleted : AppRoutes.liveTracking,
            RideArgs(ride.id),
          ),
        ),
      );
    }
    if (ride.status.isOver) {
      return ('This ride isn’t happening any more', const RideCardActions());
    }
    if (p.iAmDriver) {
      if (!ride.isOpen) {
        return ('Booked with another Ride Partner', const RideCardActions());
      }
      if (ride.offered) {
        return (
          'You offered · waiting for $name to confirm',
          RideCardActions(
            secondary: 'Withdraw offer',
            onSecondary: () => _act(p.withdraw, 'Offer withdrawn.'),
          ),
        );
      }
      return (
        '$name needs a ride',
        RideCardActions(
          primary: 'I can help',
          onPrimary: () => _act(p.offer, 'Offer sent to $name.'),
        ),
      );
    }
    if (p.pendingOffer != null) {
      return (
        '$name offered to drive',
        RideCardActions(
          primary: 'Approve',
          onPrimary: () =>
              _act(() => p.respond(approve: true), 'Ride booked with $name!'),
          secondary: 'Decline',
          onSecondary: () =>
              _act(() => p.respond(approve: false), 'Offer declined.'),
        ),
      );
    }
    if (ride.status.isBooked) {
      return ('Booked with another Ride Partner', const RideCardActions());
    }
    return ('Waiting for a Ride Partner', const RideCardActions());
  }
}
