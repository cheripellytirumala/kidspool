import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../core/constants/messages_api_constants.dart';
import '../../core/utils/messages_format.dart';
import '../../domain/entities/chat_person.dart';
import '../../domain/entities/ride_chat.dart';
import '../../domain/entities/ride_request.dart';
import '../../domain/usecases/get_drive_request.dart';
import '../../domain/usecases/get_my_ride_request.dart';
import '../../domain/usecases/get_ride_messages.dart';
import '../../domain/usecases/offer_ride.dart';
import '../../domain/usecases/respond_to_offer.dart';
import '../../domain/usecases/send_ride_message.dart';
import '../../domain/usecases/withdraw_offer.dart';

/// F19 · a ride chat: the ride request / offer / booking card plus the
/// messages between the parent and one Ride Partner.
///
/// The open thread is polled every [pollInterval] while the screen is
/// visible ([startPolling] / [stopPolling]). When the chat RPCs aren't on
/// the server ([chatMissing]) polling stops and the composer is disabled;
/// the ride card and its actions keep working.
class RideChatProvider extends ChangeNotifier {
  RideChatProvider({
    required GetMyRideRequest getMyRideRequest,
    required GetDriveRequest getDriveRequest,
    required GetRideMessages getRideMessages,
    required SendRideMessage sendRideMessage,
    required RespondToOffer respondToOffer,
    required OfferRide offerRide,
    required WithdrawOffer withdrawOffer,
    this.pollInterval = MessagesApiConstants.threadPollInterval,
  }) : _getMine = getMyRideRequest,
       _getDrive = getDriveRequest,
       _getMessages = getRideMessages,
       _send = sendRideMessage,
       _respond = respondToOffer,
       _offerRide = offerRide,
       _withdraw = withdrawOffer;

  final GetMyRideRequest _getMine;
  final GetDriveRequest _getDrive;
  final GetRideMessages _getMessages;
  final SendRideMessage _send;
  final RespondToOffer _respond;
  final OfferRide _offerRide;
  final WithdrawOffer _withdraw;
  final Duration pollInterval;

  RideChatArgs? _args;
  RideRequest? _ride;
  ViewStatus _rideStatus = ViewStatus.initial;
  String? _rideError;

  List<ChatMessage> _messages = const [];
  ViewStatus _messagesStatus = ViewStatus.initial;
  String? _messagesError;
  bool _chatMissing = false;

  bool _sending = false;
  bool _busy = false;
  Timer? _poll;
  bool _polling = false;
  bool _inFlight = false;
  bool _disposed = false;

  RideChatArgs? get args => _args;
  bool get hasChat => _args != null;
  bool get iAmDriver => _args?.iAmDriver ?? false;
  RideRequest? get ride => _ride;
  ViewStatus get rideStatus => _rideStatus;
  String? get rideError => _rideError;
  List<ChatMessage> get messages => _messages;
  ViewStatus get messagesStatus => _messagesStatus;
  String? get messagesError => _messagesError;
  bool get chatMissing => _chatMissing;
  bool get sending => _sending;
  bool get busy => _busy;
  bool get isPolling => _poll != null;
  String? get myUserId => _getMessages.myUserId;

  bool isMine(ChatMessage message) => message.isMine(myUserId);

  /// The parent on the other end of this chat.
  ChatPerson get other {
    final a = _args;
    final r = _ride;
    ChatPerson? person;
    if (r != null && a != null) {
      if (a.iAmDriver) {
        person = r.parent;
      } else {
        person =
            r.offerFrom(a.driverId)?.partner ??
            (r.driver?.id == a.driverId ? r.driver : null);
      }
    }
    if (person != null) return person;
    final name = a?.otherName?.trim();
    final first = name == null || name.isEmpty ? 'Parent' : name;
    return ChatPerson(
      firstName: first,
      initials: a?.otherInitials ?? MessagesFormat.initials(first),
    );
  }

  /// Pending offer from this chat's Ride Partner (parent view).
  RideOffer? get pendingOffer {
    final a = _args;
    if (a == null || a.iAmDriver) return null;
    return _ride?.offerFrom(a.driverId);
  }

  /// The ride is booked with this chat's Ride Partner.
  bool get bookedHere {
    final r = _ride;
    final a = _args;
    if (r == null || a == null || !r.status.isBooked) return false;
    return a.iAmDriver || r.driver?.id == a.driverId;
  }

  // -------------------------------------------------------------- load

  Future<void> open(RideChatArgs? args) async {
    _args = args;
    if (args == null) {
      _rideStatus = ViewStatus.failure;
      _rideError = 'We couldn’t find this chat. Open it from Messages.';
      _notify();
      return;
    }
    await Future.wait([loadRide(), refreshMessages(initial: true)]);
  }

  Future<void> loadRide() async {
    final a = _args;
    if (a == null) return;
    _rideStatus = ViewStatus.loading;
    _notify();
    final result = a.iAmDriver
        ? await _getDrive(a.requestId)
        : await _getMine(a.requestId);
    if (_disposed) return;
    result.match(
      (failure) {
        _rideStatus = ViewStatus.failure;
        _rideError = failure.message;
      },
      (ride) {
        _ride = ride;
        _rideStatus = ViewStatus.success;
        _rideError = null;
      },
    );
    _notify();
  }

  Future<void> refreshMessages({bool initial = false}) async {
    final a = _args;
    if (a == null || _chatMissing || _inFlight || _disposed) return;
    _inFlight = true;
    if (initial) {
      _messagesStatus = ViewStatus.loading;
      _notify();
    }
    final result = await _getMessages(
      ChatRef(requestId: a.requestId, driverId: a.driverId),
    );
    _inFlight = false;
    if (_disposed) return;
    result.match(_onMessagesFailure, (messages) {
      _messagesStatus = ViewStatus.success;
      _messagesError = null;
      if (!listEquals(messages, _messages)) _messages = messages;
    });
    _notify();
  }

  void _onMessagesFailure(Failure failure) {
    if (failure.code == MessagesApiConstants.chatMissing) {
      _chatMissing = true;
      _messagesStatus = ViewStatus.success;
      _messagesError = null;
      stopPolling();
      return;
    }
    // Keep what's on screen; show the error only when nothing loaded yet.
    if (_messages.isEmpty) {
      _messagesStatus = ViewStatus.failure;
      _messagesError = failure.message;
    }
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
    if (_args == null || _chatMissing) return;
    _poll = Timer.periodic(pollInterval, (_) => refreshMessages());
  }

  // ----------------------------------------------------------- actions

  /// Sends [text]. Returns an error message, or null when sent.
  Future<String?> send(String text) async {
    final a = _args;
    final body = text.trim();
    if (a == null || body.isEmpty || _sending) return null;
    if (_chatMissing) return MessagesApiConstants.chatMissingMessage;
    _sending = true;
    _notify();
    final result = await _send(
      SendRideMessageParams(
        requestId: a.requestId,
        driverId: a.driverId,
        body: body,
      ),
    );
    _sending = false;
    if (_disposed) return null;
    String? error;
    result.match(
      (failure) {
        if (failure.code == MessagesApiConstants.chatMissing) {
          _chatMissing = true;
          stopPolling();
        }
        error = failure.message;
      },
      (message) {
        if (!_messages.any((m) => m.id == message.id)) {
          _messages = [..._messages, message];
        }
        _messagesStatus = ViewStatus.success;
        _messagesError = null;
      },
    );
    _notify();
    return error;
  }

  /// Parent: approve / decline this Ride Partner's offer.
  Future<String?> respond({required bool approve}) async {
    final offer = pendingOffer;
    if (offer == null || _busy) return null;
    return _run(
      () => _respond(
        RespondToOfferParams(offerId: offer.offerId, approve: approve),
      ),
    );
  }

  /// Ride Partner: "I can help" from the request card.
  Future<String?> offer() async {
    final r = _ride;
    if (r == null || !r.isOpen || r.offered || _busy) return null;
    return _run(() => _offerRide(r.id));
  }

  /// Ride Partner: take back the pending offer.
  Future<String?> withdraw() async {
    final offerId = _ride?.myOfferId;
    if (offerId == null || _busy) return null;
    return _run(() => _withdraw(offerId));
  }

  Future<String?> _run(
    Future<Either<Failure, Object?>> Function() action,
  ) async {
    _busy = true;
    _notify();
    final result = await action();
    final failure = result.getLeft().toNullable();
    if (failure == null) await loadRide();
    _busy = false;
    _notify();
    return failure?.message;
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
