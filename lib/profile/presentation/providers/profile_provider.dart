import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../../../common/domain/entities/picked_address.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../domain/entities/profile_overview.dart';
import '../../domain/entities/ride_mode.dart';
import '../../domain/entities/saved_address.dart';
import '../../domain/usecases/add_saved_address.dart';
import '../../domain/usecases/change_ride_mode.dart';
import '../../domain/usecases/delete_saved_address.dart';
import '../../domain/usecases/get_profile_overview.dart';
import '../../domain/usecases/set_default_address.dart';
import '../../domain/usecases/sign_out.dart';

/// State of S18 · Profile. Actions return an error message, or `null` on
/// success, so the screen can show it in a snack bar.
class ProfileProvider extends ChangeNotifier {
  ProfileProvider({
    required GetProfileOverview getOverview,
    required ChangeRideMode changeRideMode,
    required AddSavedAddress addAddress,
    required SetDefaultAddress setDefaultAddress,
    required DeleteSavedAddress deleteAddress,
    required SignOut signOut,
  }) : _getOverview = getOverview,
       _changeRideMode = changeRideMode,
       _addAddress = addAddress,
       _setDefaultAddress = setDefaultAddress,
       _deleteAddress = deleteAddress,
       _signOut = signOut;

  final GetProfileOverview _getOverview;
  final ChangeRideMode _changeRideMode;
  final AddSavedAddress _addAddress;
  final SetDefaultAddress _setDefaultAddress;
  final DeleteSavedAddress _deleteAddress;
  final SignOut _signOut;

  ViewStatus _status = ViewStatus.initial;
  Failure? _failure;
  ProfileOverview? _overview;
  bool _isSaving = false;
  final Set<String> _expandedKids = {};
  bool _disposed = false;

  ViewStatus get status => _status;
  ProfileOverview? get overview => _overview;
  String? get errorMessage => _failure?.message;

  /// First load (nothing to show yet).
  bool get isLoading => _status.isLoading && _overview == null;
  bool get isSaving => _isSaving;
  bool get showError => _status.isFailure && _overview == null;

  /// Kid cards opened to show their places (Figma 961:7601 state).
  bool isExpanded(String kidId) => _expandedKids.contains(kidId);

  void toggleKid(String kidId) {
    if (!_expandedKids.remove(kidId)) _expandedKids.add(kidId);
    _notify();
  }

  Future<void> load() async {
    if (_status.isLoading) return;
    _status = ViewStatus.loading;
    _notify();

    final result = await _getOverview(const NoParams());
    result.match(
      (failure) {
        _failure = failure;
        _status = ViewStatus.failure;
      },
      (overview) {
        _failure = null;
        _overview = overview;
        _expandedKids.retainAll(overview.kids.map((k) => k.id));
        _status = ViewStatus.success;
      },
    );
    _notify();
  }

  Future<String?> setRideMode(RideMode mode) async {
    final current = _overview;
    if (current == null || current.rideMode == mode) return null;
    return _run(
      () => _changeRideMode(mode),
      (saved) => _overview = current.copyWith(rideMode: saved),
    );
  }

  Future<String?> addAddress(PickedAddress address, String label) => _run(
    () => _addAddress(
      AddAddressParams(
        address: address,
        label: label,
        isDefault: _overview?.addresses.isEmpty ?? true,
      ),
    ),
    _setAddresses,
  );

  Future<String?> makeDefault(SavedAddress address) =>
      _run(() => _setDefaultAddress(address.id), _setAddresses);

  Future<String?> deleteAddress(SavedAddress address) =>
      _run(() => _deleteAddress(address.id), _setAddresses);

  Future<String?> signOut() => _run(() => _signOut(const NoParams()), (_) {});

  void _setAddresses(List<SavedAddress> addresses) {
    _overview = _overview?.copyWith(addresses: addresses);
  }

  Future<String?> _run<T>(
    Future<Either<Failure, T>> Function() action,
    void Function(T value) onSuccess,
  ) async {
    if (_isSaving) return null;
    _isSaving = true;
    _notify();
    final result = await action();
    _isSaving = false;
    final error = result.match((failure) => failure.message, (value) {
      onSuccess(value);
      return null;
    });
    _notify();
    return error;
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
