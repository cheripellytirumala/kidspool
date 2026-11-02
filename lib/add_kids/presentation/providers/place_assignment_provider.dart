import 'package:flutter/foundation.dart';

import '../../domain/entities/place.dart';
import 'kids_provider.dart';

/// F10 · Who goes & when: which kids go to the pending place. Schools are
/// saved on the server (`update-kid`), activities on the device.
class PlaceAssignmentProvider extends ChangeNotifier {
  PlaceAssignmentProvider(this._kids, {Place? fallbackPlace}) {
    if (fallbackPlace != null) _kids.ensurePendingPlace(fallbackPlace);
    final place = _kids.pendingPlace;
    final existing = place == null
        ? const <String>{}
        : _kids.childIdsAt(place.id);
    _selected = existing.isNotEmpty
        ? {...existing}
        : {for (final child in _kids.children) child.id};
  }

  final KidsProvider _kids;
  late Set<String> _selected;

  Place? get place => _kids.pendingPlace;
  bool isSelected(String childId) => _selected.contains(childId);
  bool get canSave => place != null && _selected.isNotEmpty;

  void toggle(String childId) {
    if (!_selected.remove(childId)) _selected.add(childId);
    notifyListeners();
  }

  bool get isSaving => _kids.isSaving;

  /// Saves the assignment. Returns an error message or `null`.
  Future<String?> save() => _kids.assignPendingPlace(_selected);
}
