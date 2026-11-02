import 'package:flutter/foundation.dart';

import '../../data/sample/home_sample_data.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/kid_place.dart';
import '../../domain/entities/ride_summary.dart';

/// F14 states: browsing families by place, or picking families to say hi to
/// about a ride.
enum FamiliesMode { browse, select }

/// Filter chips shown while selecting families.
enum FamilyFilter {
  all('All'),
  nearby('Nearby'),
  givesRide('Gives Ride'),
  needsRide('Need Ride');

  const FamilyFilter(this.label);
  final String label;
}

/// Per-screen state for "Families near you".
class FamiliesNearYouProvider extends ChangeNotifier {
  FamiliesNearYouProvider();

  /// Families within this distance count as "Nearby".
  static const double nearbyMiles = 1;

  final List<Family> _families = HomeSampleData.families;
  final List<KidPlace> places = HomeSampleData.places;
  final RideSummary ride = HomeSampleData.pendingRide;
  final String messageTemplate = HomeSampleData.messageTemplate;

  FamiliesMode _mode = FamiliesMode.browse;
  bool _startedInSelectMode = false;
  String? _placeId = HomeSampleData.lincoln.id;
  FamilyFilter _filter = FamilyFilter.all;
  final Set<String> _selectedIds = {};
  bool _useTemplate = true;
  String _customMessage = '';

  FamiliesMode get mode => _mode;
  bool get isSelecting => _mode == FamiliesMode.select;

  /// True when the screen was opened from the ask-for-a-ride flow.
  bool get startedInSelectMode => _startedInSelectMode;

  /// Selected place switch in browse mode; `null` = All.
  String? get placeId => _placeId;
  FamilyFilter get filter => _filter;

  int get totalCount => _families.length;
  int countFor(KidPlace place) =>
      _families.where((f) => f.placeIds.contains(place.id)).length;

  List<Family> get visibleFamilies => switch (_mode) {
    FamiliesMode.browse =>
      _placeId == null
          ? _families
          : _families.where((f) => f.placeIds.contains(_placeId)).toList(),
    FamiliesMode.select => _families.where(_matchesFilter).toList(),
  };

  bool _matchesFilter(Family f) => switch (_filter) {
    FamilyFilter.all => true,
    FamilyFilter.nearby => f.distanceMiles <= nearbyMiles,
    FamilyFilter.givesRide => f.givesRides,
    FamilyFilter.needsRide => f.needsRides,
  };

  bool isSelected(Family family) => _selectedIds.contains(family.id);
  int get selectedCount => _selectedIds.length;
  bool get hasSelection => _selectedIds.isNotEmpty;

  bool get allVisibleSelected {
    final visible = visibleFamilies;
    return visible.isNotEmpty && visible.every(isSelected);
  }

  /// Opens the screen straight in select mode with every family checked,
  /// as in the Figma flow after asking for a ride.
  void startInSelectMode() {
    _startedInSelectMode = true;
    _mode = FamiliesMode.select;
    _selectedIds
      ..clear()
      ..addAll(_families.map((f) => f.id));
    notifyListeners();
  }

  void selectPlace(String? placeId) {
    if (_placeId == placeId) return;
    _placeId = placeId;
    notifyListeners();
  }

  void setFilter(FamilyFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    notifyListeners();
  }

  /// Browse → select, with [family] pre-checked.
  void beginSelection(Family family) {
    _mode = FamiliesMode.select;
    _selectedIds
      ..clear()
      ..add(family.id);
    notifyListeners();
  }

  void toggle(Family family) {
    if (!_selectedIds.remove(family.id)) _selectedIds.add(family.id);
    notifyListeners();
  }

  void toggleAllVisible() {
    final ids = visibleFamilies.map((f) => f.id);
    if (allVisibleSelected) {
      _selectedIds.removeAll(ids);
    } else {
      _selectedIds.addAll(ids);
    }
    notifyListeners();
  }

  /// Select → browse.
  void cancelSelection() {
    _mode = FamiliesMode.browse;
    _selectedIds.clear();
    _filter = FamilyFilter.all;
    notifyListeners();
  }

  // Send-message sheet

  bool get useTemplate => _useTemplate;
  String get customMessage => _customMessage;

  void chooseTemplate() {
    if (_useTemplate) return;
    _useTemplate = true;
    notifyListeners();
  }

  void setCustomMessage(String value) {
    _customMessage = value;
    _useTemplate = value.trim().isEmpty;
    notifyListeners();
  }

  /// The message that will be sent to every selected parent.
  String get message => _useTemplate ? messageTemplate : _customMessage.trim();

  bool get canSend => hasSelection && message.isNotEmpty;
}
