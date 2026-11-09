import 'package:flutter/foundation.dart';

import '../../../common/core/usecase/usecase.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../core/constants/messages_api_constants.dart';
import '../../domain/entities/ride_group.dart';
import '../../domain/usecases/get_my_ride_groups.dart';

/// "Your ride groups": every group the user is in, newest activity first.
class RideGroupsProvider extends ChangeNotifier {
  RideGroupsProvider({required GetMyRideGroups getMyRideGroups})
    : _getGroups = getMyRideGroups;

  final GetMyRideGroups _getGroups;

  ViewStatus _status = ViewStatus.initial;
  List<RideGroup> _groups = const [];
  String? _error;
  bool _notSetUp = false;
  bool _disposed = false;

  ViewStatus get status => _status;
  List<RideGroup> get groups => _groups;
  String? get error => _error;

  /// The server has no group functions yet.
  bool get notSetUp => _notSetUp;
  bool get isFirstLoad => _status.isLoading && _groups.isEmpty;

  Future<void> load() async {
    if (_status.isLoading) return;
    _status = ViewStatus.loading;
    _notify();
    final result = await _getGroups(const NoParams());
    if (_disposed) return;
    result.match(
      (failure) {
        _notSetUp = failure.code == MessagesApiConstants.groupsMissing;
        _error = _notSetUp
            ? MessagesApiConstants.groupsMissingMessage
            : failure.message;
        _status = ViewStatus.failure;
      },
      (groups) {
        _groups = groups;
        _error = null;
        _notSetUp = false;
        _status = ViewStatus.success;
      },
    );
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
