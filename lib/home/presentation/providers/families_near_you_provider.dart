import 'package:flutter/foundation.dart';

import '../../../common/core/usecase/usecase.dart';
import '../../../messages/domain/usecases/get_my_ride_groups.dart';
import '../../../messages/domain/entities/ride_group.dart';
import '../../../common/core/error/failures.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../core/constants/home_api_constants.dart';
import '../../../common/domain/repositories/account_repository.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/kid_place.dart';
import '../../domain/entities/ride_summary.dart';
import '../../domain/usecases/get_families_near_me.dart';
import '../../../messages/core/constants/messages_api_constants.dart';
import '../../../messages/domain/usecases/create_ride_group.dart';
import '../../../messages/domain/usecases/send_group_message.dart';
import '../../../messages/domain/usecases/send_ride_message.dart';

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

/// Why the family list is empty (or [none] when it isn't).
enum FamiliesEmptyState {
  none,

  /// None of the user's kids has a school yet.
  noSchool,

  /// Nobody from the kids' schools nearby yet.
  noFamilies,

  /// `get_families_near_me` isn't deployed on the server.
  unavailable,

  /// The request failed; [FamiliesNearYouProvider.errorMessage] says why.
  error,
}

/// Per-screen state for "Families near you" (`get_families_near_me`).
class FamiliesNearYouProvider extends ChangeNotifier {
  FamiliesNearYouProvider({
    required GetFamiliesNearMe getFamiliesNearMe,
    AccountRepository? account,
    RideSummary? Function()? rideSummary,
    List<String> Function()? requestIds,
    SendRideMessage? sendRideMessage,
    CreateRideGroup? createRideGroup,
    SendGroupMessage? sendGroupMessage,
    Future<String?> Function()? createRide,
    String Function()? rideMessage,
    Future<String?> Function(String groupId)? askInGroup,
    GetMyRideGroups? getMyRideGroups,
  }) : _getFamiliesNearMe = getFamiliesNearMe,
       _getMyRideGroups = getMyRideGroups,
       _askInGroup = askInGroup,
       _createRide = createRide,
       _rideMessage = rideMessage,
       _createRideGroup = createRideGroup,
       _sendGroupMessage = sendGroupMessage,
       _account = account,
       _rideSummary = rideSummary,
       _requestIds = requestIds,
       _sendRideMessage = sendRideMessage;

  final GetFamiliesNearMe _getFamiliesNearMe;
  final AccountRepository? _account;

  /// The ride being asked for (from the ask-for-a-ride draft), if any.
  final RideSummary? Function()? _rideSummary;

  /// Requests just made on "Ask for a ride" (select mode); the message goes
  /// into the first one's chat with each selected parent.
  final List<String> Function()? _requestIds;
  final SendRideMessage? _sendRideMessage;
  final CreateRideGroup? _createRideGroup;
  final SendGroupMessage? _sendGroupMessage;

  /// Creates the ride from "Ask for a ride" (returns an error or null). It
  /// is only created when the parent messages families: "Say Hi" or
  /// "Start a group" — not on "Next: choose who to ask".
  final Future<String?> Function()? _createRide;

  /// Posts the pending ride as a card in a group ("I can help" there
  /// creates the request). Returns an error or null.
  final Future<String?> Function(String groupId)? _askInGroup;

  /// The ride as a chat message, posted in a group started from here.
  final String Function()? _rideMessage;
  bool _isSending = false;
  bool _isCreatingGroup = false;
  String _myFirstName = '';

  /// Families within this distance count as "Nearby".
  static const double nearbyMiles = 1;

  /// The ride summary shown in select mode; `null` hides the card.
  RideSummary? get ride => _rideSummary?.call();

  /// "Say Hi" template with the parent's first name and the shared school.
  String get messageTemplate {
    final name = _myFirstName.trim();
    final placeName = _places
        .where((p) => p.id == _placeId)
        .map((p) => p.name)
        .followedBy(_places.map((p) => p.name))
        .firstOrNull;
    final hi = name.isEmpty ? 'Hi!' : 'Hi! I’m $name.';
    final school = placeName == null
        ? 'Our kids go to the same school.'
        : 'Our kids both go to $placeName.';
    return '$hi $school Would you like to share school rides? '
        'We could take turns driving.';
  }

  ViewStatus _status = ViewStatus.initial;
  Failure? _failure;
  List<Family> _families = const [];
  List<KidPlace> _places = const [];
  bool _hasSchool = true;
  bool _selectAllOnLoad = false;

  FamiliesMode _mode = FamiliesMode.browse;
  bool _startedInSelectMode = false;
  String? _placeId;
  FamilyFilter _filter = FamilyFilter.all;
  final Set<String> _selectedIds = {};
  bool _useTemplate = true;
  String _customMessage = '';

  ViewStatus get status => _status;
  bool get isLoading => _status.isLoading;
  String? get errorMessage => _failure?.message;

  /// The server has no `get_families_near_me`: don't offer a retry.
  bool get isUnavailable =>
      _failure?.code == HomeApiConstants.familiesNearMeMissing;

  final GetMyRideGroups? _getMyRideGroups;
  List<RideGroup> _groups = const [];
  String? _sendingToGroupId;

  /// "Your chats" (scenario 2): the parent's ride groups, most recent first,
  /// shown after asking for a ride so it can go straight to one of them.
  List<RideGroup> get groups => _startedInSelectMode ? _groups : const [];

  /// The group the ride is being posted to.
  String? get sendingToGroupId => _sendingToGroupId;

  /// "Send ride" on one of [groups]: posts the pending ride there as a card
  /// (the request is created when a driver taps "I can help"). Returns an
  /// error, or null.
  Future<String?> sendRideToGroup(RideGroup group) async {
    final ask = _askInGroup;
    if (ask == null || _sendingToGroupId != null) return null;
    _sendingToGroupId = group.id;
    notifyListeners();
    final error = await ask(group.id);
    _sendingToGroupId = null;
    notifyListeners();
    return error;
  }

  /// Loads "Your chats" (also part of [load]).
  Future<void> loadGroups() async {
    final get = _getMyRideGroups;
    if (get == null) return;
    final result = await get(const NoParams());
    _groups = result.getOrElse((_) => _groups);
  }

  /// Loads the families; call on open and pull-to-refresh.
  Future<void> load() async {
    if (_status.isLoading) return;
    _status = ViewStatus.loading;
    notifyListeners();
    final groupsLoaded = loadGroups();

    final account = _account;
    if (account != null && _myFirstName.isEmpty) {
      final status = await account.getMyStatus();
      _myFirstName = status.getRight().toNullable()?.firstName ?? '';
    }
    final result = await _getFamiliesNearMe(const GetFamiliesNearMeParams());
    result.match(
      (failure) {
        _failure = failure;
        _status = ViewStatus.failure;
        // Keep what was shown before a failed refresh.
      },
      (data) {
        _failure = null;
        _status = ViewStatus.success;
        setFamilies(data.families, hasSchool: data.hasSchool);
      },
    );
    await groupsLoaded;
    notifyListeners();
  }

  /// Replaces the list (and the place chips built from it).
  @visibleForTesting
  void setFamilies(List<Family> families, {bool hasSchool = true}) {
    _families = families;
    _hasSchool = hasSchool;
    _places = placesOf(families);
    if (_placeId != null && !_places.any((p) => p.id == _placeId)) {
      _placeId = null;
    }
    final ids = {for (final f in families) f.id};
    _selectedIds.retainAll(ids);
    if (_selectAllOnLoad && families.isNotEmpty) {
      _selectAllOnLoad = false;
      _selectedIds.addAll(ids);
    }
  }

  /// One school chip per school in [families], most families first.
  static List<KidPlace> placesOf(List<Family> families) {
    final names = <String, String>{};
    final counts = <String, int>{};
    final activityIds = <String>{};
    for (final family in families) {
      for (final kid in family.kids) {
        if (kid.schoolId case final id?) {
          names.putIfAbsent(id, () => kid.schoolName);
        }
      }
      for (final a in family.activities) {
        names.putIfAbsent(a.id, () => a.name);
        activityIds.add(a.id);
      }
      for (final id in family.placeIds) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    final ids = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : names[a]!.compareTo(names[b]!);
      });
    return [
      for (final id in ids)
        KidPlace(
          id: id,
          name: names[id]!.isEmpty
              ? (activityIds.contains(id) ? 'Activity' : 'School')
              : names[id]!,
          kind: activityIds.contains(id)
              ? KidPlaceKind.activity
              : KidPlaceKind.school,
        ),
    ];
  }

  List<Family> get families => _families;
  List<KidPlace> get places => _places;

  /// What to show instead of the list.
  FamiliesEmptyState get emptyState {
    if (_families.isNotEmpty) return FamiliesEmptyState.none;
    if (isUnavailable) return FamiliesEmptyState.unavailable;
    if (_status.isFailure) return FamiliesEmptyState.error;
    if (!_status.isSuccess) return FamiliesEmptyState.none;
    return _hasSchool
        ? FamiliesEmptyState.noFamilies
        : FamiliesEmptyState.noSchool;
  }

  String? get emptyMessage => switch (emptyState) {
    FamiliesEmptyState.none => null,
    FamiliesEmptyState.noSchool =>
      'Add your kids’ school to see families going to the same places.',
    FamiliesEmptyState.noFamilies =>
      'No families from your kids’ schools nearby yet.',
    FamiliesEmptyState.unavailable =>
      'Families near you isn’t set up on the server yet.',
    FamiliesEmptyState.error =>
      errorMessage ?? 'Couldn’t load families near you. Pull to refresh.',
  };

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

  /// Families at the chosen place (F14 "All · n" / school / activity
  /// chips, in both modes); in select mode also matching the filter.
  List<Family> get visibleFamilies => [
    for (final f in _families)
      if ((_placeId == null || f.placeIds.contains(_placeId)) &&
          (_mode == FamiliesMode.browse || _matchesFilter(f)))
        f,
  ];

  bool _matchesFilter(Family f) => switch (_filter) {
    FamilyFilter.all => true,
    FamilyFilter.nearby => (f.distanceMiles ?? double.infinity) <= nearbyMiles,
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
  /// as in the Figma flow after asking for a ride (families loaded later
  /// are checked when they arrive).
  void startInSelectMode() {
    _startedInSelectMode = true;
    _mode = FamiliesMode.select;
    _selectedIds
      ..clear()
      ..addAll(_families.map((f) => f.id));
    _selectAllOnLoad = _families.isEmpty;
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

  bool get canSend => hasSelection && message.isNotEmpty && !_isSending;
  bool get isSending => _isSending;

  /// A ride request the message can be sent with (made on Ask for a ride).
  String? get _requestId => _requestIds?.call().firstOrNull;

  /// A ride is being asked for (select mode) but isn't created yet.
  bool get _rideToCreate =>
      _requestId == null &&
      _createRide != null &&
      _startedInSelectMode &&
      ride != null;

  bool get canDeliver =>
      (_requestId != null || _rideToCreate) && _sendRideMessage != null;

  /// Creates the pending ride, if any. Returns an error, or null.
  Future<String?> _ensureRide() async {
    final create = _createRide;
    if (!_rideToCreate || create == null) return null;
    _isSending = true;
    notifyListeners();
    final error = await create();
    _isSending = false;
    notifyListeners();
    return error;
  }

  /// Sends [message] to every selected parent in the ride's chat (creating
  /// the ride first when it isn't yet). Returns how many got it, or an
  /// error when none did.
  Future<(int sent, String? error)> sendMessage() async {
    if (_isSending || !canSend) return (0, null);
    final rideError = await _ensureRide();
    if (rideError != null) return (0, rideError);
    final requestId = _requestId;
    final send = _sendRideMessage;
    if (requestId == null || send == null) {
      return (0, 'Ask for a ride first — your message goes with the request.');
    }
    _isSending = true;
    notifyListeners();
    final body = message;
    // After asking for a ride: the ride is posted after the Hi.
    final ride = _startedInSelectMode ? _rideMessage?.call() : null;
    var sent = 0;
    String? lastError;
    final delivered = <String>[];
    for (final parentId in _selectedIds.toList()) {
      final result = await send(
        SendRideMessageParams(
          requestId: requestId,
          driverId: parentId,
          body: body,
        ),
      );
      final ok = result.match((f) {
        lastError = f.message;
        return false;
      }, (_) => true);
      if (!ok) continue;
      sent++;
      delivered.add(parentId);
      if (ride != null) {
        await send(
          SendRideMessageParams(
            requestId: requestId,
            driverId: parentId,
            body: ride,
          ),
        );
      }
    }
    _deliveredTo = List.unmodifiable(delivered);
    _isSending = false;
    notifyListeners();
    if (sent == 0) {
      return (0, lastError ?? 'Your message couldn’t be sent. Try again.');
    }
    return (sent, null);
  }

  List<String> _deliveredTo = const [];

  /// Parents the last Say Hi reached (their chats now have the Hi and the
  /// ride).
  List<String> get deliveredTo => _deliveredTo;

  /// The ride request the Hi went with.
  String? get rideRequestId => _requestId;

  /// The family with parent [id], if listed.
  Family? familyById(String id) =>
      _families.where((f) => f.id == id).firstOrNull;

  /// "Say Hi" with no ride request yet: the Hi goes into a new ride group
  /// with the selected families instead.
  bool get saysHiInGroup => !canDeliver && _sendGroupMessage != null;

  /// Starts a group with the selected parents (named [suggestedGroupName])
  /// and posts [message] in it. Returns the group's id and name, or an error.
  Future<(String? groupId, String name, String? error)> sayHiInGroup() async {
    final name = suggestedGroupName;
    final post = _sendGroupMessage;
    if (post == null || _isSending || !canSend) return (null, name, null);
    if (_selectedIds.length > maxGroupFamilies) {
      return (
        null,
        name,
        'Pick up to $maxGroupFamilies families to say hi in a group, or ask '
            'for a ride first.',
      );
    }
    final body = message;
    final (groupId, error) = await startGroup(name);
    if (groupId == null) return (null, name, error);
    _isSending = true;
    notifyListeners();
    final sent = await post(
      SendGroupMessageParams(groupId: groupId, body: body),
    );
    _isSending = false;
    notifyListeners();
    // The group exists either way; a failed Hi can be retyped in its chat.
    return (groupId, name, sent.getLeft().toNullable()?.message);
  }

  /// "Start a group" from select mode: creates the group and posts the
  /// pending ride in it as a card — the request is created when a driver
  /// taps "I can help".
  Future<(String? groupId, String? error)> startGroupWithRide(
    String name,
  ) async {
    if (_isSending || _isCreatingGroup) return (null, null);
    final ask = _askInGroup;
    if (_rideToCreate && ask != null) {
      final (groupId, error) = await startGroup(name);
      if (groupId == null) return (null, error);
      _isSending = true;
      notifyListeners();
      final askError = await ask(groupId);
      _isSending = false;
      notifyListeners();
      // The group exists either way; the ride can be asked again there.
      return (groupId, askError);
    }
    final rideError = await _ensureRide();
    if (rideError != null) return (null, rideError);
    final (groupId, error) = await startGroup(name);
    final post = _sendGroupMessage;
    final text = _rideMessage?.call();
    if (groupId != null && _requestId != null && post != null && text != null) {
      await post(SendGroupMessageParams(groupId: groupId, body: text));
    }
    return (groupId, error);
  }

  // Start a group

  /// Other families a new group can take (the user makes up the rest).
  static const int maxGroupFamilies = MessagesApiConstants.maxGroupMembers - 1;

  bool get isCreatingGroup => _isCreatingGroup;

  /// "Start a group" shows for 1–7 selected families.
  bool get canStartGroup =>
      _createRideGroup != null &&
      _selectedIds.isNotEmpty &&
      _selectedIds.length <= maxGroupFamilies;

  /// The school the group is about: the chosen place, else the first school
  /// every selected family shares. Null when there is none.
  KidPlace? get groupPlace {
    if (_places.where((p) => p.id == _placeId).firstOrNull case final p?) {
      return p;
    }
    final selected = _families.where((f) => _selectedIds.contains(f.id));
    if (selected.isEmpty) return null;
    return _places
        .where((p) => selected.every((f) => f.placeIds.contains(p.id)))
        .firstOrNull;
  }

  /// Prefilled group name: "Home → Lincoln Elementary".
  String get suggestedGroupName {
    final place = groupPlace?.name;
    final name = place == null ? 'Our ride group' : 'Home → $place';
    return name.length <= MessagesApiConstants.maxGroupNameLength
        ? name
        : name.substring(0, MessagesApiConstants.maxGroupNameLength);
  }

  /// Starts a group called [name] with the selected parents. Returns the
  /// new group's id, or an error message.
  Future<(String? groupId, String? error)> startGroup(String name) async {
    final create = _createRideGroup;
    if (create == null || _isCreatingGroup) return (null, null);
    if (!canStartGroup) {
      return (null, 'Pick 1 to $maxGroupFamilies families for a group.');
    }
    final place = groupPlace;
    _isCreatingGroup = true;
    notifyListeners();
    final result = await create(
      CreateRideGroupParams(
        name: name,
        memberIds: _selectedIds.toList(),
        schoolId: place?.kind == KidPlaceKind.school ? place?.id : null,
      ),
    );
    _isCreatingGroup = false;
    notifyListeners();
    return result.match(
      (failure) => (
        null,
        failure.code == MessagesApiConstants.groupsMissing
            ? MessagesApiConstants.groupsMissingMessage
            : failure.message,
      ),
      (id) => (id, null),
    );
  }
}
