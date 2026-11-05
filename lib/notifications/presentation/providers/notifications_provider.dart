import 'package:flutter/foundation.dart';

import '../../../common/presentation/state/view_state.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';

/// State of F25b · Notifications. Rows newer than the last visit are
/// "new" (lime-soft) for this visit; opening the list marks them seen so
/// the Home bell dot clears.
class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider({required NotificationsRepository repository})
    : _repository = repository;

  final NotificationsRepository _repository;

  ViewStatus _status = ViewStatus.initial;
  List<AppNotification> _items = const [];
  String? _errorMessage;

  /// Seen-up-to time from before this visit (fixed while the screen is open
  /// so the highlight doesn't vanish on refresh).
  DateTime? _seenBefore;
  bool _seenCaptured = false;
  bool _disposed = false;

  ViewStatus get status => _status;
  List<AppNotification> get items => _items;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _status.isLoading && _items.isEmpty;
  bool get showError => _status.isFailure && _items.isEmpty;
  bool get showEmpty => _status.isSuccess && _items.isEmpty;

  bool isNew(AppNotification n) {
    final seen = _seenBefore;
    return seen == null || n.createdAt.isAfter(seen);
  }

  Future<void> load() async {
    if (!_seenCaptured) {
      _seenBefore = _repository.seenAt;
      _seenCaptured = true;
    }
    _status = ViewStatus.loading;
    _errorMessage = null;
    _notify();
    final result = await _repository.getNotifications();
    if (_disposed) return;
    await result.match(
      (failure) async {
        _status = ViewStatus.failure;
        _errorMessage = failure.message;
      },
      (items) async {
        _items = items;
        _status = ViewStatus.success;
        if (items.isNotEmpty) await _repository.markSeen(items.first.createdAt);
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
