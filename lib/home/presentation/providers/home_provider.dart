import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../common/core/constants/app_constants.dart';
import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../../common/domain/repositories/account_repository.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/home_role.dart';
import '../../domain/entities/ride_activity.dart';
import '../../domain/entities/upcoming_ride.dart';
import '../../domain/repositories/home_repository.dart';
import '../../domain/usecases/get_families_near_me.dart';
import '../../../messages/domain/entities/ride_group.dart';
import '../../../messages/domain/usecases/get_my_ride_groups.dart';

/// State holder for the Home dashboard: the parent's name
/// (`get_my_status`), upcoming rides (`get_my_ride_requests`), drives the
/// user gives (`get_my_drives`), the booked ride's driver and route group
/// (`get_request_activity`), the bell dot (`get_my_notifications`) and the
/// FAMILIES preview (`get_families_near_me`) and the latest ride group
/// (`get_my_ride_groups`, optional).
/// Registered as a lazy singleton so the user's role survives navigation.
class HomeProvider extends ChangeNotifier {
  HomeProvider({
    required HomeRepository repository,
    required AccountRepository account,
    required SharedPreferences preferences,
    required GetFamiliesNearMe getFamiliesNearMe,
    GetMyRideGroups? getMyRideGroups,
    DateTime Function()? clock,
    void Function(List<UpcomingRide> drives)? onDrivesLoaded,
  }) : _repository = repository,
       _onDrivesLoaded = onDrivesLoaded,
       _getRideGroups = getMyRideGroups,
       _getFamiliesNearMe = getFamiliesNearMe,
       _account = account,
       _preferences = preferences,
       _clock = clock ?? DateTime.now {
    _readRole();
  }

  /// Gets the upcoming drives after each load (ride reminders).
  final void Function(List<UpcomingRide> drives)? _onDrivesLoaded;

  /// Ride mode is chosen on About you and can be changed on Profile.
  void _readRole() {
    _role = _preferences.getString(AppConstants.cacheKeyRideRole) == 'seeker'
        ? HomeRole.needsRides
        : HomeRole.both;
  }

  final HomeRepository _repository;
  final GetFamiliesNearMe _getFamiliesNearMe;
  final GetMyRideGroups? _getRideGroups;
  final AccountRepository _account;
  final SharedPreferences _preferences;
  final DateTime Function() _clock;

  ViewStatus _status = ViewStatus.initial;
  Failure? _failure;
  HomeRole _role = HomeRole.both;
  String _firstName = '';
  List<UpcomingRide> _rides = const [];
  List<UpcomingRide> _drives = const [];
  RideActivity? _activity;
  bool _hasUnseenNotifications = false;
  List<Family> _families = const [];
  RideGroup? _latestGroup;

  ViewStatus get status => _status;
  bool get isLoading => _status.isLoading;
  String? get errorMessage => _failure?.message;

  /// Needs rides (H1e) or both (H3e), as chosen on About you.
  HomeRole get role => _role;

  void setRole(HomeRole role) {
    if (role == _role) return;
    _role = role;
    notifyListeners();
  }

  String get firstName => _firstName;

  /// "SM" — shown in the header avatar.
  String get initials => _firstName.isEmpty ? '' : _firstName[0].toUpperCase();

  /// "Hi Sarah," / "Hi there,"
  String get greeting => 'Hi ${_firstName.isEmpty ? 'there' : _firstName},';

  List<UpcomingRide> get upcomingRides => _rides;
  UpcomingRide? get nextRide => _rides.firstOrNull;

  /// Loads the name, the rides and the bell dot. Call on open and
  /// pull-to-refresh. Drives, the ride's driver and notifications are
  /// optional: their failures only hide that part of the screen.
  /// [silent]: background refresh — the screen stays as is (no spinner)
  /// and a failure keeps what's shown.
  Future<void> load({bool silent = false}) async {
    if (_status.isLoading || _silentLoading) return;
    if (silent && !_status.isSuccess) return;
    _readRole(); // pick up a change made on Profile
    if (silent) {
      _silentLoading = true;
    } else {
      _setStatus(ViewStatus.loading);
    }
    try {
      await _load(silent: silent);
    } finally {
      _silentLoading = false;
    }
  }

  bool _silentLoading = false;

  Future<void> _load({required bool silent}) async {
    final groupsF = _getRideGroups?.call(const NoParams());
    final results = await (
      _account.getMyStatus(),
      _repository.getUpcomingRides(),
      _repository.getUpcomingDrives(),
      _repository.hasUnseenNotifications(),
      _getFamiliesNearMe(const GetFamiliesNearMeParams()),
    ).wait;
    results.$1.match((_) {}, (me) => _firstName = me.firstName);
    _drives = results.$3.getOrElse((_) => const []);
    if (results.$3.isRight()) _onDrivesLoaded?.call(_drives);
    _hasUnseenNotifications = results.$4.getOrElse((_) => false);
    // Optional: a failure (or a server without the RPC) hides FAMILIES.
    _families = results.$5.match(
      (_) => silent ? _families : const [],
      (data) => data.families,
    );
    // Optional: no groups (or no groups SQL) keeps the route group card.
    if (groupsF != null) {
      _latestGroup = (await groupsF).match(
        (_) => _latestGroup,
        (groups) => groups.firstOrNull,
      );
    }
    final failure = results.$2.match((f) => f, (rides) {
      _rides = rides;
      return null;
    });

    final featured = featuredRide;
    _activity = featured == null || featured.isDrive
        ? null
        : (await _repository.getRideActivity(
            featured.id,
          )).getOrElse((_) => const RideActivity());

    if (failure != null && silent) {
      notifyListeners(); // background refresh: keep the screen as it was
    } else if (failure != null && featured == null) {
      _setStatus(ViewStatus.failure, failure: failure);
    } else {
      _setStatus(ViewStatus.success);
    }
  }

  // ---------------------------------------------------------------- H3

  /// The ride shown on the H3 map card: a kid's ride only once the driver
  /// has started it (no map before that), or a drive the user gives (they
  /// start it from the live screen). One under way first, otherwise the
  /// soonest. Null → the other layouts (upcoming rides card).
  UpcomingRide? get featuredRide {
    final booked = [
      ..._rides.where((r) => r.status == RideStatus.inProgress),
      ..._drives,
    ];
    if (booked.isEmpty) return null;
    booked.sort((a, b) {
      final live =
          (b.status == RideStatus.inProgress ? 1 : 0) -
          (a.status == RideStatus.inProgress ? 1 : 0);
      return live != 0 ? live : a.pickupAt.compareTo(b.pickupAt);
    });
    return booked.first;
  }

  bool get hasFeaturedRide => featuredRide != null;

  /// Driver and route group of [featuredRide] (kid rides only).
  RideActivity? get featuredActivity => _activity;

  /// Red dot on the bell.
  bool get hasUnseenNotifications => _hasUnseenNotifications;

  /// The bell was opened: clear the dot.
  Future<void> markNotificationsSeen() async {
    if (!_hasUnseenNotifications) return;
    _hasUnseenNotifications = false;
    notifyListeners();
    await _repository.markNotificationsSeen();
  }

  /// "Your kid’s ride" / "Your drive"
  String get featuredSectionTitle =>
      featuredRide?.isDrive ?? false ? 'Your drive' : 'Your kid’s ride';

  /// "Partner confirmed" / "On the way" / "Confirmed"
  String get featuredBadge {
    final ride = featuredRide;
    if (ride == null) return '';
    if (ride.status == RideStatus.inProgress) return 'On the way';
    return ride.isDrive ? 'Confirmed' : 'Partner confirmed';
  }

  /// "Jen drives Emma" / "You drive Mia"
  String get featuredHeadline {
    final ride = featuredRide;
    if (ride == null) return '';
    if (ride.isDrive) return 'You drive ${ride.kidsLabel}';
    final driver = _activity?.driverFirstName ?? 'Your Ride Partner';
    return '$driver drives ${ride.kidsLabel}';
  }

  /// Initials on the headline chip (driver, or the user for a drive).
  String get featuredAvatarInitials {
    final ride = featuredRide;
    if (ride == null) return '';
    if (ride.isDrive) return initials;
    final driver = _activity;
    if (driver?.driverInitials case final value? when value.isNotEmpty) {
      return value;
    }
    final name = driver?.driverFirstName ?? '';
    return name.isEmpty ? '' : name[0].toUpperCase();
  }

  String? get featuredAvatarUrl =>
      featuredRide?.isDrive ?? true ? null : _activity?.driverPhotoUrl;

  /// "Home · 8:30 AM" today, "Home · Tue 8:30 AM" on another day.
  String get featuredPickupLabel {
    final ride = featuredRide;
    if (ride == null) return '';
    final at = ride.pickupAt;
    final now = _clock();
    final today =
        at.year == now.year && at.month == now.month && at.day == now.day;
    final day = today ? '' : '${_weekdays[at.weekday - 1].substring(0, 3)} ';
    return '${ride.pickupLabel} · $day${_time(at)}';
  }

  /// "Lincoln Elementary", or the custom drop-off.
  String get featuredDestination {
    final name = featuredRide?.destinationName ?? '';
    return name.isEmpty ? 'School' : name;
  }

  /// The user's most recently active ride group, if any: "Your ride group"
  /// shows it (and opens its chat) instead of the route's parents.
  RideGroup? get latestGroup => _latestGroup;

  /// The parents on the booked ride's route. Null hides "Your ride group".
  String? get rideGroupTitle {
    final ride = featuredRide;
    if (ride == null || ride.isDrive || rideGroupMembers == 0) return null;
    return '${ride.pickupLabel} → $featuredDestination parents';
  }

  /// Parents asked for the ride plus the user.
  int get rideGroupMembers {
    final notified = _activity?.notifiedCount ?? 0;
    return notified == 0 ? 0 : notified + 1;
  }

  String get rideGroupSubtitle =>
      rideGroupMembers == 1 ? '1 member' : '$rideGroupMembers members';

  /// "Wednesday, Nov 4"
  String get dateLabel {
    final now = _clock();
    return '${_weekdays[now.weekday - 1]}, ${_months[now.month - 1]} ${now.day}';
  }

  String get emptyTitle {
    final count = _rides.length;
    if (count > 0) {
      return count == 1 ? '1 upcoming ride' : '$count upcoming rides';
    }
    return switch (_role) {
      HomeRole.needsRides => 'No rides booked.',
      HomeRole.both => 'Nothing planned today',
    };
  }

  String? get emptySubtitle {
    final next = nextRide;
    if (next != null) {
      return 'Next: ${next.title}\n${_rideWhen(next.pickupAt)} · '
          '${next.status.label}';
    }
    return switch (_role) {
      HomeRole.needsRides => null,
      HomeRole.both =>
        'Here’s your family’s week: ask for a ride or offer a seat.',
    };
  }

  /// "Tue, Nov 10 · 8:30 AM"
  String _rideWhen(DateTime at) =>
      '${_weekdays[at.weekday - 1].substring(0, 3)}, '
      '${_months[at.month - 1]} ${at.day} · ${_time(at)}';

  /// "8:30 AM"
  static String _time(DateTime at) {
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final m = at.minute.toString().padLeft(2, '0');
    return '$h:$m ${at.hour < 12 ? 'AM' : 'PM'}';
  }

  /// The nearest three families; empty hides the FAMILIES section.
  List<Family> get previewFamilies => _families.take(3).toList();

  void _setStatus(ViewStatus status, {Failure? failure}) {
    _status = status;
    _failure = failure;
    notifyListeners();
  }

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}
