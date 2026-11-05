/// Who goes to a place and when (F10). One schedule per place; siblings
/// going to the same place share it.
class Schedule {
  const Schedule({
    required this.placeId,
    required this.childIds,
    this.weekdays = const {
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    },
  });

  final String placeId;
  final Set<String> childIds;

  /// [DateTime.monday]…[DateTime.sunday].
  final Set<int> weekdays;

  Schedule copyWith({Set<String>? childIds, Set<int>? weekdays}) {
    return Schedule(
      placeId: placeId,
      childIds: childIds ?? this.childIds,
      weekdays: weekdays ?? this.weekdays,
    );
  }
}
