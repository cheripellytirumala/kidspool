import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../core/constants/messages_api_constants.dart';
import '../../domain/entities/ride_ask.dart';
import '../../domain/entities/ride_group.dart';
import '../../domain/usecases/ride_asks.dart';
import '../../core/utils/messages_format.dart';
import '../../domain/entities/ride_request.dart';
import '../../domain/usecases/get_group_messages.dart';
import '../../domain/usecases/get_requests_inbox.dart';
import '../../../common/core/usecase/usecase.dart';
import '../../domain/usecases/get_ride_group.dart';
import '../../domain/usecases/mark_group_read.dart';
import '../../domain/usecases/send_group_message.dart';

/// A ride group's chat: the group (name, members) and its messages.
///
/// Polled every [pollInterval] while the screen is visible, like the ride
/// chat. The group is marked read on open and whenever a refresh brings new
/// messages while visible. When the group RPCs aren't on the server
/// ([unavailable]) polling stops and the screen says so.
class GroupChatProvider extends ChangeNotifier {
  GroupChatProvider({
    required GetRideGroup getRideGroup,
    required GetGroupMessages getGroupMessages,
    required SendGroupMessage sendGroupMessage,
    required MarkGroupRead markGroupRead,
    GetRequestsInbox? getRequestsInbox,
    GetGroupRideAsks? getGroupRideAsks,
    HelpWithRideAsk? helpWithRideAsk,
    this.pollInterval = MessagesApiConstants.threadPollInterval,
  }) : _getGroup = getRideGroup,
       _getMessages = getGroupMessages,
       _send = sendGroupMessage,
       _markRead = markGroupRead,
       _getInbox = getRequestsInbox,
       _getAsks = getGroupRideAsks,
       _helpWithAsk = helpWithRideAsk;

  final GetGroupRideAsks? _getAsks;
  final HelpWithRideAsk? _helpWithAsk;

  /// Ride cards in this group, by the message they belong to.
  Map<String, RideAsk> _asks = const {};
  bool _asksMissing = false;
  String? _helpingId;

  /// The ride card on [message], if it is one.
  RideAsk? askFor(GroupMessage message) => _asks[message.id];

  /// The ride card whose "I can help" is being sent.
  String? get helpingId => _helpingId;

  final GetRequestsInbox? _getInbox;

  final GetRideGroup _getGroup;
  final GetGroupMessages _getMessages;
  final SendGroupMessage _send;
  final MarkGroupRead _markRead;
  final Duration pollInterval;

  GroupChatArgs? _args;
  RideGroupDetails? _group;
  ViewStatus _groupStatus = ViewStatus.initial;
  String? _groupError;

  List<GroupMessage> _messages = const [];
  ViewStatus _messagesStatus = ViewStatus.initial;
  String? _messagesError;
  bool _unavailable = false;

  bool _sending = false;
  Timer? _poll;
  bool _polling = false;
  bool _inFlight = false;
  bool _disposed = false;

  /// Id of the newest message already marked read.
  String? _readUpTo;

  GroupChatArgs? get args => _args;
  bool get hasGroup => _args != null;
  String? get groupId => _args?.groupId;
  RideGroupDetails? get group => _group;
  ViewStatus get groupStatus => _groupStatus;
  String? get groupError => _groupError;
  List<GroupMessage> get messages => _messages;
  ViewStatus get messagesStatus => _messagesStatus;
  String? get messagesError => _messagesError;
  bool get sending => _sending;
  bool get isPolling => _poll != null;
  String? get myUserId => _getMessages.myUserId;

  /// The group RPCs aren't deployed ([MessagesApiConstants.groupsMissing]).
  bool get unavailable => _unavailable;

  bool isMine(GroupMessage message) => message.isMine(myUserId);

  /// Header title: the loaded name, else the one passed in the route.
  String get title {
    final name = _group?.name ?? _args?.name;
    return name == null || name.trim().isEmpty ? 'Ride group' : name;
  }

  /// "6 members" once the group is loaded.
  String? get subtitle {
    final g = _group;
    return g == null ? null : RideGroupDetails.membersText(g.memberCount);
  }

  // -------------------------------------------------------------- load

  Future<void> open(GroupChatArgs? args) async {
    _args = args;
    if (args == null) {
      _groupStatus = ViewStatus.failure;
      _groupError = 'We couldn’t find this group. Open it from Messages.';
      _notify();
      return;
    }
    await Future.wait([loadGroup(), refreshMessages(initial: true)]);
  }

  Future<void> loadGroup() async {
    final id = groupId;
    if (id == null || _unavailable) return;
    if (_group == null) {
      _groupStatus = ViewStatus.loading;
      _notify();
    }
    final result = await _getGroup(id);
    if (_disposed) return;
    result.match(
      (failure) {
        if (_isMissing(failure)) return;
        _groupStatus = ViewStatus.failure;
        _groupError = failure.message;
      },
      (group) {
        _group = group;
        _groupStatus = ViewStatus.success;
        _groupError = null;
      },
    );
    _notify();
  }

  Future<void> refreshMessages({bool initial = false}) async {
    final id = groupId;
    if (id == null || _unavailable || _inFlight || _disposed) return;
    _inFlight = true;
    if (initial) {
      _messagesStatus = ViewStatus.loading;
      _notify();
    }
    final (result, _) = await (_getMessages(id), _loadAsks(id)).wait;
    _inFlight = false;
    if (_disposed) return;
    result.match(
      (failure) {
        if (_isMissing(failure)) return;
        // Keep what's on screen; show the error only when nothing loaded.
        if (_messages.isEmpty) {
          _messagesStatus = ViewStatus.failure;
          _messagesError = failure.message;
        }
      },
      (messages) {
        _messagesStatus = ViewStatus.success;
        _messagesError = null;
        if (!listEquals(messages, _messages)) _messages = messages;
        if (initial || _polling) _markReadIfNew();
      },
    );
    _notify();
  }

  /// Ride cards (quiet: a failure keeps the last ones; no SQL → none).
  Future<void> _loadAsks(String groupId) async {
    final get = _getAsks;
    if (get == null || _asksMissing) return;
    final result = await get(groupId);
    result.match((failure) {
      if (failure.code == MessagesApiConstants.rideAsksMissing) {
        _asksMissing = true;
      }
    }, (asks) => _asks = {for (final a in asks) ?a.messageId: a});
  }

  /// A taken ride card that isn't about the signed-in parent: hidden.
  bool isHidden(GroupMessage message) =>
      _asks[message.id]?.hiddenForMe ?? false;

  /// "I can help" on [ask]: the server creates the parent's request and
  /// books it with this driver (first come, first served). Returns an
  /// error message (null on success) and whether someone else already
  /// took it.
  Future<({String? error, bool taken})> help(RideAsk ask) async {
    final helpWith = _helpWithAsk;
    if (helpWith == null || _helpingId != null) {
      return (error: null, taken: false);
    }
    _helpingId = ask.id;
    _notify();
    final result = await helpWith(ask.id);
    _helpingId = null;
    if (_disposed) return (error: null, taken: false);
    final failure = result.getLeft().toNullable();
    await refreshMessages(); // a taken card disappears
    _notify();
    return (
      error: failure?.message,
      taken: const {
        'already_taken',
        'request_not_open',
      }.contains(failure?.code),
    );
  }

  /// `mark_ride_group_read` when there is something newer than last time.
  void _markReadIfNew() {
    final id = groupId;
    final newest = _messages.isEmpty ? '' : _messages.last.id;
    if (id == null || newest == _readUpTo) return;
    _readUpTo = newest;
    unawaited(_markRead(id));
  }

  /// Turns [MessagesApiConstants.groupsMissing] into [unavailable].
  bool _isMissing(Failure failure) {
    if (failure.code != MessagesApiConstants.groupsMissing) return false;
    _unavailable = true;
    _groupStatus = ViewStatus.success;
    _messagesStatus = ViewStatus.success;
    _groupError = null;
    _messagesError = null;
    stopPolling();
    return true;
  }

  // ----------------------------------------------------------- polling

  /// Polls the thread while the screen is visible.
  void startPolling() {
    _polling = true;
    _schedule();
  }

  /// Pauses polling (app in background, another screen on top).
  void stopPolling() {
    _polling = false;
    _poll?.cancel();
    _poll = null;
  }

  void _schedule() {
    if (!_polling || _poll != null || _disposed) return;
    if (_args == null || _unavailable) return;
    _poll = Timer.periodic(pollInterval, (_) => refreshMessages());
  }

  // -------------------------------------------------------- "+ Ride"

  /// The user's own ride requests still waiting for a Ride Partner, soonest
  /// first ("+ Ride" shares one of them in the group).
  Future<List<RideRequest>> myOpenRides({DateTime? now}) async {
    final getInbox = _getInbox;
    if (getInbox == null) return const [];
    final result = await getInbox(const NoParams());
    final at = now ?? DateTime.now();
    final rides = result.match(
      (_) => const <RideRequest>[],
      (inbox) => [
        for (final r in inbox.mine)
          if (r.isOpen && r.pickupAt.isAfter(at)) r,
      ],
    );
    return rides..sort((a, b) => a.pickupAt.compareTo(b.pickupAt));
  }

  /// `Casey · Saved → Lincoln Elementary · Tue, Nov 10 · 6:00 PM` (also the
  /// row label in the "+ Ride" sheet).
  static String rideSummary(RideRequest r) {
    final at = r.pickupAt.toLocal();
    return [
      if (r.kidNames.isNotEmpty) MessagesFormat.names(r.kidNames),
      '${r.pickupLabel} → ${r.destinationName}',
      '${MessagesFormat.shortWeekday(at)}, ${MessagesFormat.monthDay(at)} · '
          '${MessagesFormat.clock(at)}',
    ].join(' · ');
  }

  /// The message posted for a shared ride (group messages are text only).
  static String rideShareText(RideRequest r) =>
      '🚗 Ride needed: ${rideSummary(r)}. Can anyone help? '
      'Offer from Messages → Requests.';

  /// Posts [ride] in the group. Returns an error message, or null.
  Future<String?> shareRide(RideRequest ride) => send(rideShareText(ride));

  // ----------------------------------------------------------- actions

  /// Sends [text]. Returns an error message, or null when sent.
  Future<String?> send(String text) async {
    final id = groupId;
    final body = text.trim();
    if (id == null || body.isEmpty || _sending) return null;
    if (_unavailable) return MessagesApiConstants.groupsMissingMessage;
    _sending = true;
    _notify();
    final result = await _send(SendGroupMessageParams(groupId: id, body: body));
    _sending = false;
    if (_disposed) return null;
    String? error;
    result.match(
      (failure) {
        _isMissing(failure);
        error = failure.message;
      },
      (message) {
        if (!_messages.any((m) => m.id == message.id)) {
          _messages = [..._messages, message];
        }
        _readUpTo = message.id;
        _messagesStatus = ViewStatus.success;
        _messagesError = null;
      },
    );
    _notify();
    return error;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    super.dispose();
  }
}
