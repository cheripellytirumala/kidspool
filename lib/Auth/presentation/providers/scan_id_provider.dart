import 'package:flutter/foundation.dart';

/// Side of the driver's license being captured on V1.
enum IdSide { front, back }

/// UI state of the V1 "Scan your driver's license" screen: which side is
/// being captured. The photos themselves live in `AuthFlowProvider`.
class ScanIdProvider extends ChangeNotifier {
  IdSide _side = IdSide.front;
  bool _busy = false;

  IdSide get side => _side;
  bool get isBusy => _busy;

  /// "Front side · hold steady".
  String instruction({required bool frontDone, required bool backDone}) {
    if (_busy) return 'Opening camera…';
    final label = _side == IdSide.front ? 'Front' : 'Back';
    final done = _side == IdSide.front ? frontDone : backDone;
    return done ? '$label side ✓ · tap to retake' : '$label side · hold steady';
  }

  void selectSide(IdSide side) {
    if (side == _side) return;
    _side = side;
    notifyListeners();
  }

  void setBusy(bool value) {
    if (value == _busy) return;
    _busy = value;
    notifyListeners();
  }

  /// Moves on to the side still missing after a capture.
  void advance({required bool frontDone, required bool backDone}) {
    final next = !frontDone
        ? IdSide.front
        : !backDone
        ? IdSide.back
        : _side;
    if (next == _side) return;
    _side = next;
    notifyListeners();
  }
}
