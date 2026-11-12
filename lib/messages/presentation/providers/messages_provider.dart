import 'package:flutter/foundation.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../core/constants/messages_api_constants.dart';
import '../../domain/entities/chat_person.dart';
import '../../domain/entities/ride_chat.dart';
import '../../domain/entities/ride_group.dart';
import '../../domain/entities/ride_request.dart';
import '../../domain/usecases/get_my_chats.dart';
import '../../domain/usecases/get_my_ride_groups.dart';
import '../../domain/usecases/get_requests_inbox.dart';
import '../../domain/usecases/offer_ride.dart';
import '../../domain/usecases/pass_ride_request.dart';
import '../../domain/usecases/respond_to_offer.dart';
import '../../domain/usecases/withdraw_offer.dart';

enum MessagesTab { requests, chats }

/// A row of the Chats tab: a ride chat or a ride group.
sealed class ChatsItem {
  const ChatsItem();

  DateTime? get lastAt;
}

class RideChatItem extends ChatsItem {
  const RideChatItem(this.chat);

  final RideChat chat;

  @override
  DateTime? get lastAt => chat.lastAt;
}

class RideGroupItem extends ChatsItem {
  const RideGroupItem(this.group);

  final RideGroup group;

  @override
  DateTime? get lastAt => group.lastAt;
}

/// F24 · Messages (Chats tab) and F24a · Requests tab.
///
/// Requests come from the live ride RPCs. Chats come from
/// `get_my_ride_chats`; ride threads that have no messages yet (an offer on
/// the user's request, the user's own offer) are added from the requests, so
/// the tab still lists them while the chat SQL isn't applied. Ride groups
/// (`get_my_ride_groups`) are listed with them; while the groups SQL isn't
/// applied, or the groups fail to load, there are simply no group rows.
class MessagesProvider extends ChangeNotifier {
  MessagesProvider({
    required GetRequestsInbox getRequestsInbox,
    required GetMyChats getMyChats,
    required OfferRide offerRide,
    required PassRideRequest passRideRequest,
    required WithdrawOffer withdrawOffer,
    required RespondToOffer respondToOffer,
    required String? Function() myUserId,
    GetMyRideGroups? getMyRideGroups,
    void Function(int count)? onBadgeChanged,
    bool Function(RideChat chat)? isChatHidden,
  }) : _onBadgeChanged = onBadgeChanged,
       _isChatHidden = isChatHidden,
       _getGroups = getMyRideGroups,
       _getInbox = getRequestsInbox,
       _getChats = getMyChats,
       _offerRide = offerRide,
       _pass = passRideRequest,
       _withdraw = withdrawOffer,
       _respond = respondToOffer,
       _myUserId = myUserId;

  final GetRequestsInbox _getInbox;
  final GetMyChats _getChats;
  final GetMyRideGroups? _getGroups;
  final OfferRide _offerRide;
  final PassRideRequest _pass;
  final WithdrawOffer _withdraw;
  final RespondToOffer _respond;
  final String? Function() _myUserId;

  /// Receives the bottom-nav Messages count after each change.
  final void Function(int count)? _onBadgeChanged;

  /// Chats the user deleted ("Delete chat"), until someone writes again.
  final bool Function(RideChat chat)? _isChatHidden;

  bool _hidden(RideChat chat) => _isChatHidden?.call(chat) ?? false;

  MessagesTab _tab = MessagesTab.chats;
  String _query = '';

  ViewStatus _requestsStatus = ViewStatus.initial;
  String? _requestsError;
  RequestsInbox _inbox = const RequestsInbox();

  ViewStatus _chatsStatus = ViewStatus.initial;
  String? _chatsError;
  List<RideChat> _chats = const [];
  bool _chatMissing = false;

  List<RideGroup> _groups = const [];
  bool _groupsMissing = false;

  /// Request / offer id with an action in flight.
  String? _busyId;
  bool _disposed = false;

  MessagesTab get tab => _tab;
  String get query => _query;
  ViewStatus get requestsStatus => _requestsStatus;
  String? get requestsError => _requestsError;
  ViewStatus get chatsStatus => _chatsStatus;
  String? get chatsError => _chatsError;
  String? get busyId => _busyId;
  String? get myUserId => _myUserId();

  /// The chat RPCs aren't deployed (`chat_not_deployed`).
  bool get chatMissing => _chatMissing;

  /// Badge on the Requests tab.
  int get requestsBadge => _inbox.needsAnswerCount;

  /// Badge on the Chats tab: chats and groups with unread messages.
  int get chatsBadge =>
      _chats.where((c) => c.hasUnread && !_hidden(c)).length +
      _groups.where((g) => g.hasUnread).length;

  /// The user's ride groups, newest first (unfiltered).
  List<RideGroup> get groups => _groups;

  bool _matches(Iterable<String?> fields) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return fields.any((f) => f != null && f.toLowerCase().contains(q));
  }

  /// Requests sent to the user as a Ride Partner.
  List<RideRequest> get incoming => [
    for (final r in _inbox.incoming)
      if (_matches([r.parent?.firstName, r.destinationName, ...r.kidNames])) r,
  ];

  /// The user's own open requests (with offers).
  List<RideRequest> get mine => [
    for (final r in _inbox.mine)
      if (_matches([
        r.destinationName,
        ...r.kidNames,
        for (final o in r.offers) o.partner.firstName,
      ]))
        r,
  ];

  /// Place of the ride behind [chat] ("Lincoln Elementary"), shown as the
  /// chat row's last line; null when the request isn't in the inbox.
  String? chatPlace(RideChat chat) {
    for (final r in [..._inbox.mine, ..._inbox.incoming]) {
      if (r.id == chat.requestId) {
        return r.destinationName.isEmpty ? null : r.destinationName;
      }
    }
    return null;
  }

  /// Chats, newest first: server chats plus ride threads without messages.
  List<RideChat> get chats {
    final byKey = <String, RideChat>{
      for (final c in _chats) '${c.requestId}|${c.driverId}': c,
    };
    for (final c in _rideThreads()) {
      byKey.putIfAbsent('${c.requestId}|${c.driverId}', () => c);
    }
    final list = byKey.values
        .where((c) => !_hidden(c))
        .where((c) => _matches([c.other.firstName, c.lastMessage]))
        .toList();
    list.sort((a, b) {
      final at = a.lastAt, bt = b.lastAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return list;
  }

  /// The Chats tab: ride chats and ride groups, newest activity first.
  List<ChatsItem> get items {
    final list = <ChatsItem>[
      for (final c in chats) RideChatItem(c),
      for (final g in _groups)
        if (_matches([g.name, g.lastMessage])) RideGroupItem(g),
    ];
    // Stable: equal times keep chats before groups.
    final indexed = list.indexed.toList()
      ..sort((a, b) {
        final at = a.$2.lastAt, bt = b.$2.lastAt;
        final byTime = at == null && bt == null
            ? 0
            : at == null
            ? 1
            : bt == null
            ? -1
            : bt.compareTo(at);
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
    return [for (final (_, item) in indexed) item];
  }

  /// Threads implied by the requests (offers on mine, my offers on theirs).
  List<RideChat> _rideThreads() {
    final me = _myUserId();
    return [
      for (final r in _inbox.mine)
        for (final o in r.offers)
          if (o.partner.id != null)
            RideChat(
              requestId: r.id,
              driverId: o.partner.id!,
              iAmDriver: false,
              status: r.status,
              other: o.partner,
              lastMessage: '${o.partner.firstName} offered to drive',
              lastAt: o.createdAt,
            ),
      if (me != null)
        for (final r in _inbox.incoming)
          if (r.offered)
            RideChat(
              requestId: r.id,
              driverId: me,
              iAmDriver: true,
              status: r.status,
              other:
                  r.parent ??
                  const ChatPerson(firstName: 'Parent', initials: 'P'),
              lastMessage: 'You offered to drive',
            ),
    ];
  }

  /// Loads both tabs.
  /// [silent]: background refresh, the lists stay on screen (no spinner).
  Future<void> load({bool silent = false}) => Future.wait([
    loadRequests(silent: silent),
    loadChats(silent: silent),
    loadGroups(),
  ]);

  Future<void> refresh() => load();

  Future<void> loadRequests({bool silent = false}) async {
    if (!silent) {
      _requestsStatus = ViewStatus.loading;
      _notify();
    }
    final result = await _getInbox(const NoParams());
    if (_disposed) return;
    // A failed background refresh keeps what's on screen.
    if (silent && result.isLeft()) return;
    result.match(
      (failure) {
        _requestsStatus = ViewStatus.failure;
        _requestsError = failure.message;
      },
      (inbox) {
        _inbox = inbox;
        _requestsStatus = ViewStatus.success;
        _requestsError = null;
      },
    );
    _notify();
  }

  Future<void> loadChats({bool silent = false}) async {
    if (_chatMissing) return;
    if (!silent) {
      _chatsStatus = ViewStatus.loading;
      _notify();
    }
    final result = await _getChats(const NoParams());
    if (_disposed) return;
    if (silent && result.isLeft()) return;
    result.match(
      (failure) {
        if (failure.code == MessagesApiConstants.chatMissing) {
          _chatMissing = true;
          _chats = const [];
          _chatsStatus = ViewStatus.success;
          _chatsError = null;
        } else {
          _chatsStatus = ViewStatus.failure;
          _chatsError = failure.message;
        }
      },
      (chats) {
        _chats = chats;
        _chatsStatus = ViewStatus.success;
        _chatsError = null;
      },
    );
    _notify();
  }

  /// Loads the ride groups. Quiet: a failure (or a server without the
  /// groups SQL) keeps the last list and shows no error.
  Future<void> loadGroups() async {
    final get = _getGroups;
    if (get == null || _groupsMissing) return;
    final result = await get(const NoParams());
    if (_disposed) return;
    result.match((failure) {
      if (failure.code == MessagesApiConstants.groupsMissing) {
        _groupsMissing = true;
        _groups = const [];
      }
    }, (groups) => _groups = groups);
    _notify();
  }

  void selectTab(MessagesTab tab) {
    if (_tab == tab) return;
    _tab = tab;
    _notify();
  }

  void search(String query) {
    if (_query == query) return;
    _query = query;
    _notify();
  }

  // ----------------------------------------------------------- actions

  /// "I can help". Returns the outcome, or an error message.
  Future<(OfferOutcome?, String?)> offer(RideRequest request) async {
    if (_busyId != null) return (null, null);
    _busyId = request.id;
    _notify();
    final result = await _offerRide(request.id);
    final outcome = result.getRight().toNullable();
    if (outcome != null) await loadRequests();
    _busyId = null;
    _notify();
    return (outcome, _message(result.getLeft().toNullable()));
  }

  /// "Not this time" (hidden on this device).
  Future<void> pass(RideRequest request) async {
    await _pass(request.id);
    if (_disposed) return;
    _inbox = RequestsInbox(
      mine: _inbox.mine,
      incoming: [
        for (final r in _inbox.incoming)
          if (r.id != request.id) r,
      ],
    );
    _notify();
  }

  /// Takes back the user's pending offer. Returns an error message or null.
  Future<String?> withdraw(RideRequest request) async {
    final offerId = request.myOfferId;
    if (offerId == null || _busyId != null) return null;
    _busyId = request.id;
    _notify();
    final result = await _withdraw(offerId);
    if (result.isRight()) await loadRequests();
    _busyId = null;
    _notify();
    return _message(result.getLeft().toNullable());
  }

  /// Approves / declines a Ride Partner's offer. Returns an error or null.
  Future<String?> respond(RideOffer offer, {required bool approve}) async {
    if (_busyId != null) return null;
    _busyId = offer.offerId;
    _notify();
    final result = await _respond(
      RespondToOfferParams(offerId: offer.offerId, approve: approve),
    );
    if (result.isRight()) await loadRequests();
    _busyId = null;
    _notify();
    return _message(result.getLeft().toNullable());
  }

  static String? _message(Failure? failure) => failure?.message;

  void _notify() {
    if (_disposed) return;
    // Same total as MessagesBadgeCounter, once the requests are known.
    if (_requestsStatus.isSuccess) {
      _onBadgeChanged?.call(requestsBadge + chatsBadge);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
