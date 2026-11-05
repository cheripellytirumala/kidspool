import 'package:dio/dio.dart';

import '../../../../common/core/constants/api_constants.dart';
import '../../../../common/core/error/exceptions.dart';
import '../../../../common/core/network/api_client.dart';
import '../../../../common/core/utils/json_parser.dart';
import '../../../core/constants/kids_api_constants.dart';
import '../../../domain/entities/child.dart';
import '../../../domain/entities/geo_point.dart';
import '../../../domain/entities/place.dart';

/// Throws only `AppException` subtypes; never returns raw JSON.
abstract interface class KidsRemoteDataSource {
  Future<List<Map<String, dynamic>>> getMyKids();

  /// Signed URLs for private `kid-photos` paths, keyed by path.
  Future<Map<String, String>> signPhotoUrls(List<String> paths);

  Future<String> addKid(ChildDraft draft);

  Future<void> updateKid(ChildDraft draft);

  /// Changes only the school of [kidId].
  Future<void> updateKidSchool(String kidId, String schoolId);

  Future<void> deleteKid(String kidId);

  /// `school_from_place`: the `schools.id` for a Google [place]. Throws a
  /// [ServerException] with code [schoolFromPlaceMissing] when the RPC
  /// isn't on the server yet.
  Future<String> schoolFromPlace(Place place);

  /// Default saved address (`get_my_addresses`), or `null`.
  Future<GeoPoint?> getHomeLocation();
}

/// [ServerException.code] when `school_from_place` isn't deployed.
const String schoolFromPlaceMissing = 'school_from_place_missing';

class KidsRemoteDataSourceImpl implements KidsRemoteDataSource {
  const KidsRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<Map<String, dynamic>>> getMyKids() {
    return _apiClient.rpc(KidsApiConstants.getMyKids, parser: _asList);
  }

  @override
  Future<Map<String, String>> signPhotoUrls(List<String> paths) async {
    if (paths.isEmpty) return const {};
    final storageBase = '${_apiClient.baseUrl}${ApiConstants.storagePrefix}';
    return _apiClient.post(
      '${ApiConstants.storagePrefix}/object/sign/${KidsApiConstants.kidPhotosBucket}',
      data: {'expiresIn': KidsApiConstants.signedUrlSeconds, 'paths': paths},
      parser: (json) {
        final urls = <String, String>{};
        if (json is! List) return urls;
        for (final item in json.whereType<Map>()) {
          final path = item['path'];
          final signed = item['signedURL'] ?? item['signedUrl'];
          if (path is String && signed is String) {
            urls[path] = signed.startsWith('http')
                ? signed
                : '$storageBase$signed';
          }
        }
        return urls;
      },
    );
  }

  @override
  Future<String> addKid(ChildDraft draft) async {
    // School and school ID card are optional here: the school is chosen
    // later on "Where do your kids go?" (F08/F09) and saved with update-kid.
    final card = draft.newSchoolIdCardPath;
    final form = FormData.fromMap({
      ..._fields(draft),
      if (card != null) 'schoolIdCard': await MultipartFile.fromFile(card),
      if (draft.newPhotoPath != null)
        'photo': await MultipartFile.fromFile(draft.newPhotoPath!),
    });
    return _apiClient.invokeFunction(
      KidsApiConstants.addKid,
      data: form,
      parser: (json) {
        final id = json is Map ? json['kidId'] : null;
        if (id is! String) throw const ParsingException();
        return id;
      },
    );
  }

  @override
  Future<void> updateKid(ChildDraft draft) async {
    final form = FormData.fromMap({
      'kidId': draft.id,
      ..._fields(draft),
      if (draft.newSchoolIdCardPath != null)
        'schoolIdCard': await MultipartFile.fromFile(
          draft.newSchoolIdCardPath!,
        ),
      if (draft.newPhotoPath != null)
        'photo': await MultipartFile.fromFile(draft.newPhotoPath!),
    });
    await _apiClient.invokeFunction<void>(
      KidsApiConstants.updateKid,
      data: form,
      parser: (_) {},
    );
  }

  @override
  Future<void> updateKidSchool(String kidId, String schoolId) {
    return _apiClient.invokeFunction<void>(
      KidsApiConstants.updateKid,
      data: FormData.fromMap({'kidId': kidId, 'schoolId': schoolId}),
      parser: (_) {},
    );
  }

  @override
  Future<void> deleteKid(String kidId) {
    return _apiClient.invokeFunction<void>(
      KidsApiConstants.deleteKid,
      data: {'kidId': kidId},
      parser: (_) {},
    );
  }

  @override
  Future<String> schoolFromPlace(Place place) async {
    try {
      return await _apiClient.rpc(
        KidsApiConstants.schoolFromPlace,
        params: schoolFromPlaceParams(place),
        parser: (json) {
          final id = json is Map ? json['id'] : null;
          if (id is! String || id.isEmpty) throw const ParsingException();
          return id;
        },
      );
    } on ServerException catch (e) {
      final notDeployed =
          e.data['code'] == KidsApiConstants.functionNotFound ||
          (e.statusCode == 404 && e.code == null);
      if (!notDeployed) rethrow;
      throw ServerException(
        'School search from Google isn’t set up on the server yet.',
        e.statusCode,
        schoolFromPlaceMissing,
        e.data,
      );
    }
  }

  /// Params of `school_from_place`; names match the SQL arguments.
  static Map<String, dynamic> schoolFromPlaceParams(Place place) {
    String? text(String v) => v.trim().isEmpty ? null : v.trim();
    return {
      'placeId': place.googlePlaceId ?? place.id,
      'name': place.name.trim(),
      'addressLine': text(place.addressLine),
      'city': text(place.city),
      'state': text(place.state),
      'zip': text(place.zip),
      'latitude': place.latitude,
      'longitude': place.longitude,
    };
  }

  @override
  Future<GeoPoint?> getHomeLocation() {
    return _apiClient.rpc(
      KidsApiConstants.getMyAddresses,
      parser: (json) => homeFromAddresses(_asList(json)),
    );
  }

  /// The default address's coordinates (else the first with coordinates).
  static GeoPoint? homeFromAddresses(List<Map<String, dynamic>> rows) {
    GeoPoint? first;
    for (final row in rows) {
      final lat = row.readDouble('latitude');
      final lng = row.readDouble('longitude');
      if (lat == null || lng == null) continue;
      final point = GeoPoint(lat, lng);
      if (row.readBool('isDefault') ?? false) return point;
      first ??= point;
    }
    return first;
  }

  /// Text fields shared by add/update. Empty optional values clear them.
  static Map<String, dynamic> _fields(ChildDraft d) => {
    'firstName': d.firstName.trim(),
    'lastName': d.lastName.trim(),
    'dateOfBirth': _date(d.dateOfBirth),
    'grade': d.grade ?? '',
    // Omitted when not chosen yet (update-kid would reject an empty id).
    if (d.schoolId != null) 'schoolId': d.schoolId,
    'healthNotes': d.medicalNotes.trim(),
    'needsBooster': d.needsBooster.toString(),
  };

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static List<Map<String, dynamic>> _asList(dynamic json) {
    if (json is! List) throw const ParsingException();
    return json
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }
}
