import 'package:fpdart/fpdart.dart';

import '../../data/data_sources/local/kid_activities_store.dart'
    show KidActivity;
import '../../../common/core/error/failures.dart';
import '../entities/child.dart';
import '../entities/geo_point.dart';
import '../entities/place.dart';

/// Kids contract. Methods return `Future<Either<Failure, T>>`.
abstract interface class KidsRepository {
  /// The parent's kids, with signed URLs for their photos.
  Future<Either<Failure, List<Child>>> getKids();

  /// Creates (`add-kid`) or updates (`update-kid`) a kid. Returns its id.
  Future<Either<Failure, String>> saveKid(ChildDraft draft);

  Future<Either<Failure, Unit>> deleteKid(String id);

  /// The `schools.id` for a school picked from Google search
  /// (`school_from_place`; the same Google place always gives the same id).
  Future<Either<Failure, String>> schoolFromPlace(Place place);

  /// Coordinates of the parent's default saved address, or `null`.
  Future<Either<Failure, GeoPoint?>> homeLocation();

  /// Sets [schoolId] as the school of every kid in [kidIds].
  Future<Either<Failure, Unit>> assignSchool({
    required Set<String> kidIds,
    required String schoolId,
  });

  /// Saves the parent's activities on the server (best effort).
  Future<Either<Failure, Unit>> setActivities(List<KidActivity> activities);

  Future<Either<Failure, List<KidActivity>>> getActivities();

  /// Schools / activity places KidPool already knows (no Google quota).
  Future<Either<Failure, List<Place>>> searchSavedPlaces(
    PlaceKind kind,
    String query,
  );
}
