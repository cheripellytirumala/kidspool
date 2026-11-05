import 'package:flutter/foundation.dart';

import '../../../common/presentation/state/view_state.dart';
import '../../domain/entities/ride_request.dart';
import '../../domain/usecases/cancel_ride_request.dart';
import '../../domain/usecases/get_drive_request.dart';
import '../../domain/usecases/get_my_ride_request.dart';
import '../../domain/usecases/get_request_activity.dart';
import '../../domain/usecases/offer_ride.dart';
import '../../domain/usecases/pass_ride_request.dart';
import '../../domain/usecases/respond_to_offer.dart';
import '../../domain/usecases/withdraw_offer.dart';

/// A7a · a ride request. The Ride Partner's view (offer / pass / withdraw)
/// or, for the user's own request, its offers (approve / decline) and
/// cancel.
class RideRequestDetailProvider extends ChangeNotifier {
  RideRequestDetailProvider({
    required GetMyRideRequest getMyRideRequest,
    required GetDriveRequest getDriveRequest,
    required GetRequestActivity getRequestActivity,
    required OfferRide offerRide,
    required PassRideRequest passRideRequest,
    required WithdrawOffer withdrawOffer,
    required RespondToOffer respondToOffer,
    required CancelRideRequest cancelRideRequest,
    required String? Function() myUserId,
  }) : _myUserId = myUserId,
       _getMine = getMyRideRequest,
       _getDrive = getDriveRequest,
       _getActivity = getRequestActivity,
       _offerRide = offerRide,
       _pass = passRideRequest,
       _withdraw = withdrawOffer,
       _respond = respondToOffer,
       _cancel = cancelRideRequest;

  final GetMyRideRequest _getMine;
  final GetDriveRequest _getDrive;
  final GetRequestActivity _getActivity;
  final OfferRide _offerRide;
  final PassRideRequest _pass;
  final WithdrawOffer _withdraw;
  final RespondToOffer _respond;
  final CancelRideRequest _cancel;
  final String? Function() _myUserId;

  String? _requestId;
  bool _isMine = false;
  RideRequest? _request;
  RequestActivity? _activity;
  ViewStatus _status = ViewStatus.initial;
  String? _errorMessage;
  bool _busy = false;
  bool _disposed = false;

  RideRequest? get request => _request;
  RequestActivity? get activity => _activity;
  ViewStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get hasRequest => _requestId != null;
  bool get isMine => _isMine;
  bool get busy => _busy;

  /// `profiles.id` of the signed-in user (the chat's driver id after an offer).
  String? get myUserId => _myUserId();

  Future<void> open(String? requestId, {required bool isMine}) async {
    _requestId = requestId;
    _isMine = isMine;
    if (requestId == null) {
      _status = ViewStatus.failure;
      _errorMessage = 'We couldn’t find this request. Open it from Messages.';
      _notify();
      return;
    }
    _status = ViewStatus.loading;
    _notify();
    final result = isMine
        ? await _getMine(requestId)
        : await _getDrive(requestId);
    if (_disposed) return;
    result.match(
      (failure) {
        _status = ViewStatus.failure;
        _errorMessage = failure.message;
      },
      (request) {
        _request = request;
        _status = ViewStatus.success;
        _errorMessage = null;
      },
    );
    _notify();
    if (isMine && _request != null) {
      final activity = await _getActivity(requestId);
      if (_disposed) return;
      _activity = activity.getRight().toNullable();
      _notify();
    }
  }

  Future<void> retry() => open(_requestId, isMine: _isMine);

  /// "Yes, I can help". Returns (outcome, error).
  Future<(OfferOutcome?, String?)> offer() async {
    final r = _request;
    if (r == null || _busy) return (null, null);
    _setBusy(true);
    final result = await _offerRide(r.id);
    final outcome = result.getRight().toNullable();
    if (outcome != null) {
      _request = r.copyWith(
        myOfferId: outcome.offerId,
        status: outcome.confirmed ? RideRequestStatus.confirmed : null,
      );
    }
    _setBusy(false);
    return (outcome, result.getLeft().toNullable()?.message);
  }

  /// "Can't this time".
  Future<void> pass() async {
    final r = _request;
    if (r == null) return;
    await _pass(r.id);
  }

  Future<String?> withdraw() async {
    final r = _request;
    final offerId = r?.myOfferId;
    if (r == null || offerId == null || _busy) return null;
    _setBusy(true);
    final result = await _withdraw(offerId);
    if (result.isRight()) _request = r.copyWith(clearMyOffer: true);
    _setBusy(false);
    return result.getLeft().toNullable()?.message;
  }

  Future<String?> respond(RideOffer offer, {required bool approve}) async {
    final r = _request;
    if (r == null || _busy) return null;
    _setBusy(true);
    final result = await _respond(
      RespondToOfferParams(offerId: offer.offerId, approve: approve),
    );
    final failure = result.getLeft().toNullable();
    if (failure == null) {
      final remaining = [
        for (final o in r.offers)
          if (o.offerId != offer.offerId && !approve) o,
      ];
      _request = r.copyWith(
        offers: remaining,
        status: approve ? RideRequestStatus.confirmed : null,
        driver: approve
            ? (result.getRight().toNullable() ?? offer.partner)
            : null,
      );
    }
    _setBusy(false);
    return failure?.message;
  }

  /// Cancels the user's own request (this day).
  Future<String?> cancel() async {
    final r = _request;
    if (r == null || _busy) return null;
    _setBusy(true);
    final result = await _cancel(r.id);
    if (result.isRight()) {
      _request = r.copyWith(status: RideRequestStatus.cancelled);
    }
    _setBusy(false);
    return result.getLeft().toNullable()?.message;
  }

  void _setBusy(bool value) {
    _busy = value;
    _notify();
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
