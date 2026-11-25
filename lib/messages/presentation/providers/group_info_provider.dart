import 'package:flutter/foundation.dart';

import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../../home/domain/entities/family.dart';
import '../../../home/domain/usecases/get_families_near_me.dart';
import '../../core/constants/messages_api_constants.dart';
import '../../domain/entities/ride_group.dart';
import '../../domain/usecases/add_group_members.dart';
import '../../domain/usecases/get_group_candidates.dart';
import '../../domain/usecases/get_ride_group.dart';
import '../../domain/usecases/leave_ride_group.dart';
import '../../domain/usecases/rename_ride_group.dart';
import '../../domain/usecases/set_group_muted.dart';

/// A ride group's info: members, Add members, Rename, Mute, Leave.
class GroupInfoProvider extends ChangeNotifier {
  GroupInfoProvider({
    required GetRideGroup getRideGroup,
    required GetGroupCandidates getGroupCandidates,
    required AddGroupMembers addGroupMembers,
    required RenameRideGroup renameRideGroup,
    required SetGroupMuted setGroupMuted,
    required LeaveRideGroup leaveRideGroup,
    GetFamiliesNearMe? getFamiliesNearMe,
  }) : _getGroup = getRideGroup,
       _getFamiliesNearMe = getFamiliesNearMe,
       _getCandidates = getGroupCandidates,
       _addMembers = addGroupMembers,
       _rename = renameRideGroup,
       _setMuted = setGroupMuted,
       _leave = leaveRideGroup;

  final GetRideGroup _getGroup;
  final GetGroupCandidates _getCandidates;
  final AddGroupMembers _addMembers;
  final RenameRideGroup _rename;
  final SetGroupMuted _setMuted;
  final LeaveRideGroup _leave;

  /// "Add members" source: Families near you. Without it (older wiring,
  /// tests) the server's own candidate list is used.
  final GetFamiliesNearMe? _getFamiliesNearMe;

  GroupChatArgs? _args;
  RideGroupDetails? _group;
  ViewStatus _status = ViewStatus.initial;
  String? _error;
  bool _busy = false;
  bool _disposed = false;

  ViewStatus _candidatesStatus = ViewStatus.initial;
  String? _candidatesError;
  List<RideGroupMember> _candidates = const [];

  bool get hasGroup => _args != null;
  String? get groupId => _args?.groupId;
  RideGroupDetails? get group => _group;
  ViewStatus get status => _status;
  String? get errorMessage => _error;
  bool get busy => _busy;

  ViewStatus get candidatesStatus => _candidatesStatus;
  String? get candidatesError => _candidatesError;
  List<RideGroupMember> get candidates => _candidates;

  /// Families that can still be added (0 when full or not loaded).
  int get remainingSlots => _group?.remainingSlots ?? 0;
  bool get isFull => _group?.isFull ?? false;

  Future<void> open(GroupChatArgs? args) async {
    _args = args;
    if (args == null) {
      _status = ViewStatus.failure;
      _error = 'We couldn’t find this group. Open it from Messages.';
      _notify();
      return;
    }
    await load();
  }

  Future<void> load() async {
    final id = groupId;
    if (id == null) return;
    if (_group == null) {
      _status = ViewStatus.loading;
      _notify();
    }
    final result = await _getGroup(id);
    if (_disposed) return;
    result.match(
      (failure) {
        _status = ViewStatus.failure;
        _error = failure.code == MessagesApiConstants.groupsMissing
            ? MessagesApiConstants.groupsMissingMessage
            : failure.message;
      },
      (group) {
        _group = group;
        _status = ViewStatus.success;
        _error = null;
      },
    );
    _notify();
  }

  // ------------------------------------------------------- add parents

  /// Loads who can be added: the families near the user (nearest first),
  /// minus the people already in the group.
  Future<void> loadCandidates() async {
    final id = groupId;
    if (id == null) return;
    _candidatesStatus = ViewStatus.loading;
    _notify();
    final nearby = _getFamiliesNearMe;
    final result = nearby == null
        ? await _getCandidates(id)
        : (await nearby(
            const GetFamiliesNearMeParams(),
          )).map((found) => found.families.map(_candidateFrom).toList());
    if (_disposed) return;
    result.match(
      (failure) {
        _candidatesStatus = ViewStatus.failure;
        _candidatesError = failure.message;
      },
      (list) {
        final inGroup = {for (final m in _group?.members ?? const []) m.id};
        _candidates = [
          for (final c in list)
            if (!inGroup.contains(c.id)) c,
        ];
        _candidatesStatus = ViewStatus.success;
        _candidatesError = null;
      },
    );
    _notify();
  }

  static RideGroupMember _candidateFrom(Family f) => RideGroupMember(
    id: f.id,
    firstName: f.parentName,
    initials: f.initials,
    kids: {
      for (final k in f.kids)
        if (k.firstName.isNotEmpty) k.firstName,
    }.toList(),
    distanceMiles: f.distanceMiles,
  );

  /// Adds [memberIds]. Returns how many joined, or an error message.
  Future<(int, String?)> addMembers(List<String> memberIds) async {
    final id = groupId;
    if (id == null || memberIds.isEmpty || _busy) return (0, null);
    _setBusy(true);
    final result = await _addMembers(
      AddGroupMembersParams(groupId: id, memberIds: memberIds),
    );
    if (result.isRight()) await load();
    _setBusy(false);
    return result.match((f) => (0, f.message), (added) => (added, null));
  }

  // ----------------------------------------------------------- actions

  /// Returns an error message, or null when renamed.
  Future<String?> rename(String name) async {
    final id = groupId;
    if (id == null || _busy) return null;
    _setBusy(true);
    final result = await _rename(
      RenameRideGroupParams(groupId: id, name: name),
    );
    final error = result.getLeft().toNullable()?.message;
    if (error == null) _group = _group?.copyWith(name: name.trim());
    _setBusy(false);
    return error;
  }

  /// Optimistic; reverts and returns an error message on failure.
  Future<String?> setMuted(bool muted) async {
    final id = groupId;
    final group = _group;
    if (id == null || group == null) return null;
    _group = group.copyWith(muted: muted);
    _notify();
    final result = await _setMuted(
      SetGroupMutedParams(groupId: id, muted: muted),
    );
    final error = result.getLeft().toNullable()?.message;
    if (error != null) {
      _group = _group?.copyWith(muted: !muted);
      _notify();
    }
    return error;
  }

  /// Returns an error message, or null once the user has left.
  Future<String?> leave() async {
    final id = groupId;
    if (id == null || _busy) return null;
    _setBusy(true);
    final result = await _leave(id);
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
