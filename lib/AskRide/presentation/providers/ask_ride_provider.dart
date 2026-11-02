import 'package:flutter/foundation.dart';

import '../../../core/error/failures.dart';
import '../../../core/state/view_state.dart';

/// State holder for the AskRide flow. Depends on use cases only.
class AskRideProvider extends ChangeNotifier {
  ViewStatus _status = ViewStatus.initial;
  Failure? _failure;

  ViewStatus get status => _status;
  bool get isLoading => _status.isLoading;
  String? get errorMessage => _failure?.message;

  // ignore: unused_element
  void _setStatus(ViewStatus status, {Failure? failure}) {
    _status = status;
    _failure = failure;
    notifyListeners();
  }
}
