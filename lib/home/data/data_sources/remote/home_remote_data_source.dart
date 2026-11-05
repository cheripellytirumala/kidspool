import '../../../../common/core/error/exceptions.dart';
import '../../../../common/core/network/api_client.dart';
import '../../../../common/core/utils/json_parser.dart';
import '../../../core/constants/home_api_constants.dart';
import '../../models/family_model.dart';
import '../../../domain/entities/family.dart';
import '../../../domain/entities/ride_activity.dart';
import '../../../domain/entities/upcoming_ride.dart';

/// Throws only `AppException` subtypes; never returns raw JSON.
abstract interface class HomeRemoteDataSource {
  Future<List<UpcomingRide>> getUpcomingRides();

  Future<List<UpcomingRide>> getUpcomingDrives();

  Future<RideActivity> getRideActivity(String requestId);

  /// `createdAt` of the newest notification, or null when there are none.
  Future<DateTime?> getLatestNotificationAt();

  /// Other parents whose kids share a school with the user's kids, nearest
  /// first. Throws a `ServerException` with code
  /// [HomeApiConstants.familiesNearMeMissing] when the RPC isn't deployed.
  Future<List<Family>> getFamiliesNearMe({
    String? schoolId,
    double radiusMiles = HomeApiConstants.familiesRadiusMiles,
  });

  /// True when at least one of the user's kids has a school (`get_my_kids`).
  Future<bool> hasKidWithSchool();
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  const HomeRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<UpcomingRide>> getUpcomingRides() {
    return _guard(
      () => _apiClient.rpc(
        HomeApiConstants.getMyRideRequests,
        params: const {'scope': HomeApiConstants.scopeUpcoming},
        parser: (json) {
          if (json is! List) throw const ParsingException();
          return json
              .whereType<Map>()
              .map((e) => _ride(Map<String, dynamic>.from(e)))
              .whereType<UpcomingRide>()
              .toList(growable: false);
        },
      ),
      fallback: "Couldn't load your rides. Please try again.",
    );
  }

  /// `get_my_drives(upcoming)` → `{drives: [...], pendingOffers: [...]}`.
  /// Only `drives` (approved, or under way) are rides the user gives.
  @override
  Future<List<UpcomingRide>> getUpcomingDrives() {
    return _guard(
      () => _apiClient.rpc(
        HomeApiConstants.getMyDrives,
        params: const {'scope': HomeApiConstants.scopeUpcoming},
        parser: (json) {
          if (json is! Map) throw const ParsingException();
          final drives = json['drives'];
          if (drives is! List) return const <UpcomingRide>[];
          return drives
              .whereType<Map>()
              .map((e) => _drive(Map<String, dynamic>.from(e)))
              .whereType<UpcomingRide>()
              .toList(growable: false)
            ..sort((a, b) => a.pickupAt.compareTo(b.pickupAt));
        },
      ),
      fallback: "Couldn't load your drives. Please try again.",
    );
  }

  /// `{requestId, status, notifiedCount, seenCount, offersCount,
  /// notifiedDrivers, driverCancelledAt, driver}` — `driver` is
  /// `driver_card_json` (`firstName`, `initials`, …) once one is approved.
  @override
  Future<RideActivity> getRideActivity(String requestId) {
    return _guard(
      () => _apiClient.rpc(
        HomeApiConstants.getRequestActivity,
        params: {'requestId': requestId},
        parser: (json) {
          if (json is! Map) throw const ParsingException();
          final map = Map<String, dynamic>.from(json);
          final driverJson = map['driver'];
          final driver = driverJson is Map
              ? Map<String, dynamic>.from(driverJson)
              : const <String, dynamic>{};
          final first = driver.readString('firstName')?.trim();
          return RideActivity(
            driverFirstName: first == null || first.isEmpty ? null : first,
            driverInitials: driver.readString('initials'),
            driverPhotoUrl:
                driver.readString('photoUrl') ?? driver.readString('avatarUrl'),
            notifiedCount: map.readInt('notifiedCount') ?? 0,
          );
        },
      ),
      fallback: "Couldn't check on your ride. Pull to refresh.",
    );
  }

  @override
  Future<DateTime?> getLatestNotificationAt() {
    return _guard(
      () => _apiClient.rpc(
        HomeApiConstants.getMyNotifications,
        parser: (json) {
          if (json is! List) throw const ParsingException();
          DateTime? latest;
          for (final row in json.whereType<Map>()) {
            final at = DateTime.tryParse(row['createdAt']?.toString() ?? '');
            if (at != null && (latest == null || at.isAfter(latest))) {
              latest = at;
            }
          }
          return latest;
        },
      ),
      fallback: "Couldn't load your updates.",
    );
  }

  static const String familiesMissingMessage =
      'Families near you isn’t set up on the server yet.';

  @override
  Future<List<Family>> getFamiliesNearMe({
    String? schoolId,
    double radiusMiles = HomeApiConstants.familiesRadiusMiles,
  }) async {
    try {
      return await _guard(
        () => _apiClient.rpc(
          HomeApiConstants.getFamiliesNearMe,
          params: {'schoolId': ?schoolId, 'radiusMiles': radiusMiles},
          parser: parseFamilies,
        ),
        fallback: "Couldn't load families near you. Pull to refresh.",
        rethrowMissing: true,
      );
    } on ServerException catch (e) {
      if (!isMissingFunction(e)) rethrow;
      throw ServerException(
        familiesMissingMessage,
        e.statusCode,
        HomeApiConstants.familiesNearMeMissing,
        e.data,
      );
    }
  }

  /// `get_families_near_me` JSON → families (rows without an id skipped).
  static List<Family> parseFamilies(dynamic json) {
    if (json is! List) throw const ParsingException();
    return json
        .whereType<Map>()
        .map((e) => FamilyModel.fromJson(Map<String, dynamic>.from(e)))
        .whereType<Family>()
        .toList(growable: false);
  }

  /// PostgREST answers 404 / `PGRST202` for an RPC that isn't deployed.
  static bool isMissingFunction(ServerException e) =>
      e.data['code'] == HomeApiConstants.functionNotFound ||
      (e.statusCode == 404 && e.code == null);

  @override
  Future<bool> hasKidWithSchool() {
    return _guard(
      () => _apiClient.rpc(
        HomeApiConstants.getMyKids,
        parser: (json) {
          if (json is! List) throw const ParsingException();
          return json.whereType<Map>().any((kid) {
            final school = kid['school'];
            final id = school is Map ? school['id'] : kid['schoolId'];
            return id is String && id.isNotEmpty;
          });
        },
      ),
      fallback: "Couldn't load your kids.",
    );
  }

  /// Turns the RPCs' `raise ... using message = '<code>'` errors into
  /// messages for the parent.
  static Future<T> _guard<T>(
    Future<T> Function() call, {
    required String fallback,
    bool rethrowMissing = false,
  }) async {
    try {
      return await call();
    } on UnauthorizedException {
      rethrow;
    } on ServerException catch (e) {
      if (rethrowMissing && isMissingFunction(e)) rethrow;
      final code = e.code ?? e.message;
      throw ServerException(
        switch (code) {
          'not_authenticated' => 'Your session expired. Please sign in again.',
          'not_found' ||
          'request_not_found' => "This ride isn't available any more.",
          _ => fallback,
        },
        e.statusCode,
        e.code,
        e.data,
      );
    }
  }

  /// A `get_my_ride_requests` row (`ride_request_json`); public for tests.
  static UpcomingRide? parseRide(Map<String, dynamic> json) => _ride(json);

  /// A `get_my_drives` row; public for tests.
  static UpcomingRide? parseDrive(Map<String, dynamic> json) => _drive(json);

  static UpcomingRide? _ride(Map<String, dynamic> json) {
    final pickupAt = DateTime.tryParse(json.readString('pickupAt') ?? '');
    final id = json.readString('id');
    if (pickupAt == null || id == null) return null;
    final school = json['school'];
    final address = json['pickupAddress'];
    return UpcomingRide(
      id: id,
      status: RideStatus.parse(json.readString('status')),
      kidNames: _kidNames(json),
      schoolName: school is Map ? (school['name']?.toString() ?? '') : '',
      pickupAt: pickupAt.toLocal(),
      pickupLabel: address is Map
          ? (address['label']?.toString() ?? 'Home')
          : 'Home',
      dropoffLabel: dropoffLabel(json),
    );
  }

  /// A `get_my_drives` row: the other family's request plus `parent`.
  static UpcomingRide? _drive(Map<String, dynamic> json) {
    final pickupAt = DateTime.tryParse(json.readString('pickupAt') ?? '');
    final id = json.readString('id');
    if (pickupAt == null || id == null) return null;
    final school = json['school'];
    final address = json['pickupAddress'];
    final line1 = address is Map ? address['addressLine1']?.toString() : null;
    return UpcomingRide(
      id: id,
      status: json.readString('status') == 'in_progress'
          ? RideStatus.inProgress
          : RideStatus.confirmed,
      kidNames: _kidNames(json),
      schoolName: school is Map ? (school['name']?.toString() ?? '') : '',
      pickupAt: pickupAt.toLocal(),
      pickupLabel: line1 == null || line1.trim().isEmpty
          ? 'Pickup'
          : line1.trim(),
      dropoffLabel: dropoffLabel(json),
      isDrive: true,
    );
  }

  /// `dropoff.label` (else its `addressLine1`) of a ride with a custom
  /// drop-off; `null` when the ride goes to school.
  static String? dropoffLabel(Map<String, dynamic> json) {
    final dropoff = json['dropoff'];
    if (dropoff is! Map) return null;
    for (final key in const ['label', 'addressLine1']) {
      final text = dropoff[key]?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return 'Drop-off';
  }

  static List<String> _kidNames(Map<String, dynamic> json) => json
      .readList('kids', (k) => k.readString('firstName') ?? '')
      .where((n) => n.isNotEmpty)
      .toList(growable: false);
}
