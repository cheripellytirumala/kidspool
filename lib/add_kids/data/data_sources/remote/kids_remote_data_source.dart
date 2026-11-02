import 'package:dio/dio.dart';

import '../../../../common/core/constants/api_constants.dart';
import '../../../../common/core/error/exceptions.dart';
import '../../../../common/core/network/api_client.dart';
import '../../../../common/core/utils/json_parser.dart';
import '../../../core/constants/kids_api_constants.dart';
import '../../../domain/entities/child.dart';
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

  Future<List<Place>> getSchools(String search);
}

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
    final card = draft.newSchoolIdCardPath;
    if (card == null) {
      throw const ServerException(
        'Please add a photo of the school ID card.',
        400,
        'missing_field',
      );
    }
    final form = FormData.fromMap({
      ..._fields(draft),
      'schoolIdCard': await MultipartFile.fromFile(card),
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
  Future<List<Place>> getSchools(String search) {
    return _apiClient.rpc(
      KidsApiConstants.getSchools,
      params: {'search': search.trim().isEmpty ? null : search.trim()},
      parser: (json) => _asList(json).map(_school).toList(growable: false),
    );
  }

  /// Text fields shared by add/update. Empty optional values clear them.
  static Map<String, dynamic> _fields(ChildDraft d) => {
    'firstName': d.firstName.trim(),
    'lastName': d.lastName.trim(),
    'dateOfBirth': _date(d.dateOfBirth),
    'grade': d.grade ?? '',
    'schoolId': d.schoolId,
    'healthNotes': d.medicalNotes.trim(),
    'needsBooster': d.needsBooster.toString(),
  };

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static Place _school(Map<String, dynamic> json) {
    final details = [
      json.readString('addressLine'),
      json.readString('city'),
      json.readString('zip'),
    ].whereType<String>().where((p) => p.trim().isNotEmpty).join(' · ');
    return Place(
      id: json.readString('id') ?? '',
      name: json.readString('name') ?? '',
      category: PlaceCategory.school,
      details: details,
      keywords: json.readString('state') ?? '',
    );
  }

  static List<Map<String, dynamic>> _asList(dynamic json) {
    if (json is! List) throw const ParsingException();
    return json
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }
}
