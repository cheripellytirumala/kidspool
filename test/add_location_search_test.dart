import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/add_kids/domain/entities/geo_point.dart';
import 'package:kidspool/add_kids/domain/entities/place.dart';
import 'package:kidspool/add_kids/domain/usecases/get_home_location.dart';
import 'package:kidspool/add_kids/domain/usecases/search_kid_places.dart';
import 'package:kidspool/add_kids/presentation/providers/place_search_provider.dart';
import 'package:kidspool/common/core/error/failures.dart';
import 'package:kidspool/common/core/usecase/usecase.dart';

class _Search implements SearchKidPlaces {
  final List<String> queries = [];

  @override
  Future<Either<Failure, List<Place>>> call(SearchKidPlacesParams p) async {
    queries.add(p.query);
    return const Right([]);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Home implements GetHomeLocation {
  @override
  Future<Either<Failure, GeoPoint?>> call(NoParams p) async =>
      const Right(null);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('Add location: nothing is searched until something is typed', () async {
    final search = _Search();
    final p = PlaceSearchProvider(
      searchPlaces: search,
      getHomeLocation: _Home(),
    )..open(PlaceKind.school);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(p.isIdle, isTrue);
    expect(p.results, isEmpty);
    expect(search.queries, isEmpty, reason: 'no school suggestions');

    p.setQuery('NFC Solutions');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(p.isIdle, isFalse);
    expect(search.queries, ['NFC Solutions']);

    p.setQuery('  ');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(p.isIdle, isTrue);
    expect(search.queries, hasLength(1));
    p.dispose();
  });
}
