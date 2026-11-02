import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/error_handler.dart';
import '../../../common/core/error/failures.dart';
import '../../../common/core/utils/json_parser.dart';
import '../../../common/core/utils/logger.dart';
import '../../domain/entities/child.dart';
import '../../domain/entities/place.dart';
import '../../domain/repositories/kids_repository.dart';
import '../data_sources/local/kids_local_data_source.dart';
import '../data_sources/remote/kids_remote_data_source.dart';

/// Wrap every method body in `ErrorHandler.guard` so exceptions become
/// failures before leaving the data layer.
class KidsRepositoryImpl implements KidsRepository {
  const KidsRepositoryImpl({
    required KidsRemoteDataSource remoteDataSource,
    required KidsLocalDataSource localDataSource,
  }) : _remote = remoteDataSource,
       _local = localDataSource;

  final KidsRemoteDataSource _remote;
  // ignore: unused_field
  final KidsLocalDataSource _local;

  @override
  Future<Either<Failure, List<Child>>> getKids() => ErrorHandler.guard(
    tag: 'Kids.get',
    () async {
      final rows = await _remote.getMyKids();
      final photoPaths = [for (final row in rows) ?row.readString('photoPath')];
      Map<String, String> urls = const {};
      try {
        urls = await _remote.signPhotoUrls(photoPaths);
      } catch (e) {
        // Photos are optional: show initials rather than failing.
        AppLogger.warning('Could not sign kid photos: $e', tag: 'Kids');
      }
      return rows.map((row) => _child(row, urls)).toList(growable: false);
    },
  );

  @override
  Future<Either<Failure, String>> saveKid(ChildDraft draft) =>
      ErrorHandler.guard(tag: 'Kids.save', () async {
        if (draft.id == null) return _remote.addKid(draft);
        await _remote.updateKid(draft);
        return draft.id!;
      });

  @override
  Future<Either<Failure, Unit>> deleteKid(String id) =>
      ErrorHandler.guard(tag: 'Kids.delete', () async {
        await _remote.deleteKid(id);
        return unit;
      });

  @override
  Future<Either<Failure, List<Place>>> searchSchools(String query) =>
      ErrorHandler.guard(tag: 'Kids.schools', () => _remote.getSchools(query));

  @override
  Future<Either<Failure, Unit>> assignSchool({
    required Set<String> kidIds,
    required String schoolId,
  }) => ErrorHandler.guard(tag: 'Kids.assignSchool', () async {
    for (final id in kidIds) {
      await _remote.updateKidSchool(id, schoolId);
    }
    return unit;
  });

  static Child _child(Map<String, dynamic> json, Map<String, String> urls) {
    final school = json['school'];
    final schoolMap = school is Map ? Map<String, dynamic>.from(school) : null;
    final photoPath = json.readString('photoPath');
    return Child(
      id: json.readString('id') ?? '',
      firstName: json.readString('firstName') ?? '',
      lastName: json.readString('lastName') ?? '',
      dateOfBirth: DateTime.tryParse(json.readString('dateOfBirth') ?? ''),
      age: json.readInt('age'),
      grade: json.readString('grade'),
      medicalNotes: json.readString('healthNotes') ?? '',
      photo: photoPath == null ? null : urls[photoPath],
      schoolId: schoolMap?.readString('id'),
      schoolName: schoolMap?.readString('name'),
      needsBooster: json.readBool('needsBooster') ?? false,
      hasSchoolIdCard: json.readString('schoolIdCardPath') != null,
    );
  }
}
