import 'package:flutter/foundation.dart';

import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../core/utils/messages_format.dart';
import '../../domain/entities/chat_person.dart';
import '../../domain/entities/ride_request.dart';
import '../../domain/usecases/cancel_ride_request.dart';
import '../../domain/usecases/driver_cancel_ride.dart';
import '../../domain/usecases/get_drive_request.dart';
import '../../domain/usecases/get_my_ride_request.dart';
import '../../domain/usecases/get_request_activity.dart';
import '../../domain/usecases/withdraw_offer.dart';

/// One member row in GC6.
class GroupMember {
  const GroupMember({
    required this.person,
    required this.subtitle,
    this.isYou = false,
  });

  final ChatPerson person;
  final String subtitle;
  final bool isYou;
}

/// GC6 · Group info & members, built from the ride (there is no groups
/// table): the requesting parent, the Ride Partner, the kids, the places and
/// — for the parent — how many families the request went to.
class RideGroupInfoProvider extends ChangeNotifier {
  RideGroupInfoProvider({
    required GetMyRideRequest getMyRideRequest,
    required GetDriveRequest getDriveRequest,
    required GetRequestActivity getRequestActivity,
    required CancelRideRequest cancelRideRequest,
    required WithdrawOffer withdrawOffer,
    required DriverCancelRide driverCancelRide,
  }) : _getMine = getMyRideRequest,
       _getDrive = getDriveRequest,
       _getActivity = getRequestActivity,
       _cancel = cancelRideRequest,
       _withdraw = withdrawOffer,
       _driverCancel = driverCancelRide;

  final GetMyRideRequest _getMine;
  final GetDriveRequest _getDrive;
  final GetRequestActivity _getActivity;
  final CancelRideRequest _cancel;
  final WithdrawOffer _withdraw;
  final DriverCancelRide _driverCancel;

  RideChatArgs? _args;
  RideRequest? _ride;
  RequestActivity? _activity;
  ViewStatus _status = ViewStatus.initial;
  String? _errorMessage;
  bool _busy = false;
  bool _left = false;
  bool _disposed = false;

  RideRequest? get ride => _ride;
  RequestActivity? get activity => _activity;
  ViewStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get hasChat => _args != null;
  bool get iAmDriver => _args?.iAmDriver ?? false;
  bool get busy => _busy;

  /// The user left (cancelled / withdrew) on this screen.
  bool get left => _left;

  Future<void> open(RideChatArgs? args) async {
    _args = args;
    if (args == null) {
      _status = ViewStatus.failure;
      _errorMessage = 'We couldn’t find this ride. Open it from Messages.';
      _notify();
      return;
    }
    _status = ViewStatus.loading;
    _notify();
    final result = args.iAmDriver
        ? await _getDrive(args.requestId)
        : await _getMine(args.requestId);
    if (_disposed) return;
    result.match(
      (failure) {
        _status = ViewStatus.failure;
        _errorMessage = failure.message;
      },
      (ride) {
        _ride = ride;
        _status = ViewStatus.success;
        _errorMessage = null;
      },
    );
    _notify();
    if (!args.iAmDriver && _ride != null) {
      final activity = await _getActivity(args.requestId);
      if (_disposed) return;
      _activity = activity.getRight().toNullable();
      _notify();
    }
  }

  Future<void> retry() => open(_args);

  /// `Home → Lincoln`.
  String get title {
    final r = _ride;
    if (r == null) return 'Ride';
    return '${r.pickupLabel} → ${r.destinationName}';
  }

  /// The Ride Partner of this chat (parent view).
  ChatPerson? get partner {
    final r = _ride;
    final a = _args;
    if (r == null || a == null || a.iAmDriver) return null;
    return r.offerFrom(a.driverId)?.partner ??
        (r.driver?.id == a.driverId ? r.driver : null) ??
        (a.otherName == null
            ? null
            : ChatPerson(
                id: a.driverId,
                firstName: a.otherName!,
                initials:
                    a.otherInitials ?? MessagesFormat.initials(a.otherName!),
              ));
  }

  List<GroupMember> get members {
    final r = _ride;
    if (r == null) return const [];
    final kids = MessagesFormat.names(r.kidNames);
    final booked = r.status.isBooked;
    if (iAmDriver) {
      final parent = r.parent;
      return [
        GroupMember(
          person: const ChatPerson(firstName: 'You', initials: 'You'),
          subtitle: booked ? 'drives this ride' : 'offered to drive',
          isYou: true,
        ),
        if (parent != null)
          GroupMember(person: parent, subtitle: '$kids · needs a ride'),
      ];
    }
    final p = partner;
    return [
      GroupMember(
        person: const ChatPerson(firstName: 'You', initials: 'You'),
        subtitle: '$kids · needs a ride',
        isYou: true,
      ),
      if (p != null)
        GroupMember(
          person: p,
          subtitle: booked && r.driver?.id == p.id
              ? 'drives this ride'
              : 'offered to drive',
        ),
    ];
  }

  /// `2 members · made by Sarah · sent to 6 families`.
  String get subtitle {
    final r = _ride;
    if (r == null) return '';
    final madeBy = iAmDriver ? (r.parent?.firstName ?? 'the parent') : 'you';
    final parts = [
      '${members.length} members',
      'made by $madeBy',
      if ((_activity?.notifiedCount ?? 0) > 0)
        'sent to ${_activity!.notifiedCount} '
            '${_activity!.notifiedCount == 1 ? 'family' : 'families'}',
    ];
    return parts.join(' · ');
  }

  /// What "Leave" does now, or null when there's nothing to leave.
  String? get leaveLabel {
    final r = _ride;
    if (r == null || _left || r.status.isOver) return null;
    if (!iAmDriver) return r.isOpen ? 'Cancel this request' : 'Cancel ride';
    if (r.status.isBooked) return 'Stop driving this ride';
    if (r.offered) return 'Withdraw my offer';
    return null;
  }

  /// Runs the [leaveLabel] action. Returns an error message or null.
  Future<String?> leave() async {
    final r = _ride;
    if (r == null || _busy || leaveLabel == null) return null;
    _busy = true;
    _notify();
    final result = !iAmDriver
        ? await _cancel(r.id)
        : r.status.isBooked
        ? await _driverCancel(r.id)
        : await _withdraw(r.myOfferId!);
    final failure = result.getLeft().toNullable();
    if (failure == null) _left = true;
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
    super.dispose();
  }
}
