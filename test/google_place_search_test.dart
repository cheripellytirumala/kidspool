import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:kidspool/add_kids/data/data_sources/local/kid_activities_store.dart';
import 'package:kidspool/add_kids/data/data_sources/remote/kids_remote_data_source.dart';
import 'package:kidspool/add_kids/domain/entities/child.dart';
import 'package:kidspool/add_kids/domain/entities/geo_point.dart';
import 'package:kidspool/add_kids/domain/entities/place.dart';
import 'package:kidspool/add_kids/domain/entities/place_search_query.dart';
import 'package:kidspool/add_kids/domain/repositories/kids_repository.dart';
import 'package:kidspool/add_kids/domain/usecases/resolve_school_id.dart';
import 'package:kidspool/add_kids/domain/usecases/search_kid_places.dart';
import 'package:kidspool/common/core/error/failures.dart';
import 'package:kidspool/common/data/data_sources/remote/places_remote_data_source.dart';
import 'package:kidspool/common/data/models/place_search_result_model.dart';
import 'package:kidspool/common/domain/entities/picked_address.dart';
import 'package:kidspool/common/domain/entities/place_search_result.dart';
import 'package:kidspool/common/domain/entities/place_suggestion.dart';
import 'package:kidspool/common/domain/repositories/places_repository.dart';

const _lincoln = {
  'id': 'ChIJlincoln',
  'displayName': {'text': 'Lincoln Elementary School', 'languageCode': 'en'},
  'formattedAddress': '1200 Valencia St, San Francisco, CA 94110, USA',
  'shortFormattedAddress': '1200 Valencia St, San Francisco',
  'location': {'latitude': 37.752, 'longitude': -122.42},
  'primaryType': 'primary_school',
  'addressComponents': [
    {
      'longText': '1200',
      'shortText': '1200',
      'types': ['street_number'],
    },
    {
      'longText': 'Valencia Street',
      'shortText': 'Valencia St',
      'types': ['route'],
    },
    {
      'longText': 'San Francisco',
      'shortText': 'SF',
      'types': ['locality', 'political'],
    },
    {
      'longText': 'California',
      'shortText': 'CA',
      'types': ['administrative_area_level_1', 'political'],
    },
    {
      'longText': '94110',
      'shortText': '94110',
      'types': ['postal_code'],
    },
  ],
};

void main() {
  group('searchText response', () {
    test('parses places with address parts', () {
      final places = PlaceSearchResultModel.listFromJson({
        'places': [
          _lincoln,
          {
            'id': 'no-location',
            'displayName': {'text': 'Nowhere'},
          },
        ],
      });

      expect(places, hasLength(1));
      final p = places.single;
      expect(p.placeId, 'ChIJlincoln');
      expect(p.name, 'Lincoln Elementary School');
      expect(p.latitude, 37.752);
      expect(p.longitude, -122.42);
      expect(p.street, '1200 Valencia St');
      expect(p.city, 'San Francisco');
      expect(p.stateCode, 'CA');
      expect(p.zip, '94110');
      expect(p.shortAddress, '1200 Valencia St, San Francisco');
      expect(p.primaryType, 'primary_school');
    });

    test('empty response means no results', () {
      expect(PlaceSearchResultModel.listFromJson({}), isEmpty);
    });

    test('maps a result to a Kids place row (short address · zip)', () {
      final r = PlaceSearchResultModel.fromJson(_lincoln)!;
      final school = SearchKidPlaces.toPlace(r, PlaceKind.school);
      expect(school.id, 'ChIJlincoln');
      expect(school.googlePlaceId, 'ChIJlincoln');
      expect(school.category, PlaceCategory.school);
      expect(school.details, '1200 Valencia St, San Francisco · 94110');
      expect(school.addressLine, '1200 Valencia St');
      expect(school.state, 'CA');
    });

    test('activity categories from primaryType', () {
      expect(
        SearchKidPlaces.activityCategory('swimming_pool', 'Mission Pool'),
        PlaceCategory.swim,
      );
      expect(
        SearchKidPlaces.activityCategory('sports_club', 'Westside FC'),
        PlaceCategory.soccer,
      );
      expect(
        SearchKidPlaces.activityCategory(null, 'Bay Dance Studio'),
        PlaceCategory.dance,
      );
      expect(
        SearchKidPlaces.activityCategory('music_school', 'Harmony'),
        PlaceCategory.music,
      );
      expect(
        SearchKidPlaces.activityCategory('art_studio', 'Little Artists'),
        PlaceCategory.activity,
      );
    });

    test('request body: school type + 5 km bias around home', () {
      final body = PlacesRemoteDataSourceImpl.searchTextBody(
        'schools in 94110',
        includedType: 'school',
        nearLatitude: 37.7,
        nearLongitude: -122.4,
      );
      expect(body['textQuery'], 'schools in 94110');
      expect(body['includedType'], 'school');
      expect(body['strictTypeFiltering'], true);
      expect(body['locationBias'], {
        'circle': {
          'center': {'latitude': 37.7, 'longitude': -122.4},
          'radius': 5000.0,
        },
      });
      final activity = PlacesRemoteDataSourceImpl.searchTextBody('swim');
      expect(activity.containsKey('includedType'), isFalse);
      expect(activity.containsKey('locationBias'), isFalse);
    });
  });

  group('query building', () {
    test('zip code', () {
      expect(
        PlaceSearchQuery.build(PlaceKind.school, '94110'),
        'schools in 94110',
      );
      expect(
        PlaceSearchQuery.build(PlaceKind.school, ' 94110-1234 '),
        'schools in 94110-1234',
      );
      expect(
        PlaceSearchQuery.build(PlaceKind.activity, '94110'),
        'kids activities in 94110',
      );
    });

    test('name, address and empty', () {
      expect(
        PlaceSearchQuery.build(PlaceKind.school, 'Lincoln Elementary'),
        'Lincoln Elementary',
      );
      expect(
        PlaceSearchQuery.build(PlaceKind.school, 'Valencia St San Francisco'),
        'schools near Valencia St San Francisco',
      );
      expect(PlaceSearchQuery.build(PlaceKind.school, ''), 'schools');
      expect(
        PlaceSearchQuery.build(PlaceKind.activity, '  '),
        'kids activities',
      );
      expect(PlaceSearchQuery.build(PlaceKind.activity, 'swim'), 'swim');
    });

    test('school tab sends includedType school, activity none', () {
      expect(PlaceSearchQuery.includedType(PlaceKind.school), 'school');
      expect(PlaceSearchQuery.includedType(PlaceKind.activity), isNull);
    });
  });

  group('school_from_place', () {
    const place = Place(
      id: 'ChIJlincoln',
      name: ' Lincoln Elementary School ',
      category: PlaceCategory.school,
      googlePlaceId: 'ChIJlincoln',
      latitude: 37.752,
      longitude: -122.42,
      addressLine: '1200 Valencia St',
      city: 'San Francisco',
      state: 'CA',
      zip: '94110',
    );

    test('params match the SQL argument names', () {
      expect(KidsRemoteDataSourceImpl.schoolFromPlaceParams(place), {
        'placeId': 'ChIJlincoln',
        'name': 'Lincoln Elementary School',
        'addressLine': '1200 Valencia St',
        'city': 'San Francisco',
        'state': 'CA',
        'zip': '94110',
        'latitude': 37.752,
        'longitude': -122.42,
      });
    });

    test('blank address parts are sent as null', () {
      const bare = Place(
        id: 'p1',
        name: 'Tiny School',
        category: PlaceCategory.school,
        googlePlaceId: 'p1',
        latitude: 1,
        longitude: 2,
      );
      final params = KidsRemoteDataSourceImpl.schoolFromPlaceParams(bare);
      expect(params['addressLine'], isNull);
      expect(params['zip'], isNull);
      expect(params['placeId'], 'p1');
    });

    test('Google schools are resolved, saved schools keep their id', () async {
      final repo = _FakeKidsRepository();
      final resolve = ResolveSchoolId(repo);

      expect((await resolve(place)).toNullable(), 'school-uuid');
      expect(repo.resolved.single.googlePlaceId, 'ChIJlincoln');

      const saved = Place(
        id: 'old-uuid',
        name: 'Old',
        category: PlaceCategory.school,
      );
      expect((await resolve(saved)).toNullable(), 'old-uuid');
      expect(repo.resolved, hasLength(1));
    });

    test('home location prefers the default address', () {
      expect(
        KidsRemoteDataSourceImpl.homeFromAddresses([
          {'latitude': 1.0, 'longitude': 2.0, 'isDefault': false},
          {'latitude': 3.0, 'longitude': 4.0, 'isDefault': true},
        ]),
        const GeoPoint(3, 4),
      );
      expect(KidsRemoteDataSourceImpl.homeFromAddresses(const []), isNull);
    });
  });

  group('SearchKidPlaces', () {
    test('KidPool schools first: nearest first, no Google call', () async {
      final places = _FakePlacesRepository();
      final kids = _FakeKidsRepository()
        ..saved = const [
          Place(
            id: 'delhi',
            name: 'Doon Public School',
            category: PlaceCategory.school,
            latitude: 28.66,
            longitude: 77.10,
            isSaved: true,
          ),
          Place(
            id: 'cbe',
            name: 'Doon Public School',
            category: PlaceCategory.school,
            latitude: 10.99,
            longitude: 76.97,
            isSaved: true,
          ),
        ];
      final result = await SearchKidPlaces(places, saved: kids)(
        const SearchKidPlacesParams(
          kind: PlaceKind.school,
          query: 'doon',
          near: GeoPoint(11.01, 76.96), // Coimbatore
        ),
      );
      expect(result.toNullable()!.map((p) => p.id), ['cbe', 'delhi']);
      expect(places.queries, isEmpty);
    });

    test('"Search Google" and nothing saved both go to Google', () async {
      final places = _FakePlacesRepository();
      final kids = _FakeKidsRepository()
        ..saved = const [
          Place(
            id: 'cbe',
            name: 'Doon Public School',
            category: PlaceCategory.school,
            latitude: 10.99,
            longitude: 76.97,
            isSaved: true,
          ),
        ];
      await SearchKidPlaces(places, saved: kids)(
        const SearchKidPlacesParams(
          kind: PlaceKind.school,
          query: 'lincoln',
          online: true,
        ),
      );
      expect(places.queries, hasLength(1));

      kids.saved = const [];
      await SearchKidPlaces(places, saved: kids)(
        const SearchKidPlacesParams(kind: PlaceKind.school, query: 'lincoln'),
      );
      expect(places.queries, hasLength(2));
    });

    test('without a key shows "not set up" instead of searching', () async {
      final places = _FakePlacesRepository(configured: false);
      final result = await SearchKidPlaces(places)(
        const SearchKidPlacesParams(kind: PlaceKind.school, query: 'x'),
      );
      expect(
        result.getLeft().toNullable()?.message,
        'School search isn’t set up on this build.',
      );
      expect(places.queries, isEmpty);
    });

    test('sends the built query, type and home bias', () async {
      final places = _FakePlacesRepository();
      final result = await SearchKidPlaces(places)(
        const SearchKidPlacesParams(
          kind: PlaceKind.school,
          query: '94110',
          near: GeoPoint(37.7, -122.4),
        ),
      );
      expect(places.queries.single, ('schools in 94110', 'school', 37.7));
      expect(result.toNullable()!.single.name, 'Lincoln Elementary School');
    });

    test(
      'Text Search over quota: falls back to autocomplete + details',
      () async {
        final places = _FakePlacesRepository(overQuota: true);
        final result = await SearchKidPlaces(places)(
          const SearchKidPlacesParams(
            kind: PlaceKind.activity,
            query: 'funland',
          ),
        );
        final place = result.toNullable()!.single;
        expect(place.name, 'Funland (Dayout)');
        expect(place.googlePlaceId, 'ChIJfunland');
        expect((place.latitude, place.longitude), (10.99, 76.97));
        expect(place.city, 'Coimbatore');
        expect(places.detailsAsked, ['ChIJfunland']);

        // No text typed yet: ask for a name instead of an error.
        final empty = await SearchKidPlaces(places)(
          const SearchKidPlacesParams(kind: PlaceKind.school, query: ''),
        );
        expect(
          empty.getLeft().toNullable()?.message,
          'Type the school’s name to search.',
        );
      },
    );
  });
}

class _FakePlacesRepository implements PlacesRepository {
  _FakePlacesRepository({this.configured = true, this.overQuota = false});

  final bool configured;

  /// Text Search answers 429 (daily quota used up).
  final bool overQuota;
  final List<String> detailsAsked = [];
  final List<(String, String?, double?)> queries = [];

  @override
  Future<bool> isSearchConfigured() async => configured;

  @override
  Future<Either<Failure, List<PlaceSearchResult>>> searchText(
    String query, {
    String? includedType,
    double? nearLatitude,
    double? nearLongitude,
    double radiusMeters = 5000,
  }) async {
    queries.add((query, includedType, nearLatitude));
    if (overQuota) {
      return const Left(
        ServerFailure(
          'Too many attempts. Please wait a moment.',
          statusCode: 429,
        ),
      );
    }
    return Right([PlaceSearchResultModel.fromJson(_lincoln)!]);
  }

  @override
  Future<Either<Failure, List<PlaceSuggestion>>> search(
    String query, {
    required String sessionToken,
    double? nearLatitude,
    double? nearLongitude,
  }) async => const Right([
    PlaceSuggestion(
      placeId: 'ChIJfunland',
      primaryText: 'Funland (Dayout)',
      secondaryText: 'Nanjundapuram, Coimbatore',
    ),
  ]);

  @override
  Future<Either<Failure, PickedAddress>> details(
    String placeId, {
    required String sessionToken,
  }) async {
    detailsAsked.add(placeId);
    return const Right(
      PickedAddress(
        latitude: 10.99,
        longitude: 76.97,
        street: '22 Nanjundapuram Rd',
        city: 'Coimbatore',
        stateCode: 'TN',
        zip: '641036',
        formatted: '22 Nanjundapuram Rd, Coimbatore',
      ),
    );
  }

  @override
  Future<Either<Failure, PickedAddress>> addressAt(double lat, double lng) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, PickedAddress>> currentLocation() =>
      throw UnimplementedError();
}

class _FakeKidsRepository implements KidsRepository {
  final List<Place> resolved = [];

  @override
  Future<Either<Failure, Unit>> setActivities(
    List<KidActivity> activities,
  ) async => const Right(unit);

  @override
  Future<Either<Failure, List<KidActivity>>> getActivities() async =>
      const Right([]);

  /// Saved schools / activities KidPool already knows.
  List<Place> saved = const [];

  @override
  Future<Either<Failure, List<Place>>> searchSavedPlaces(
    PlaceKind kind,
    String query,
  ) async => Right(saved);

  @override
  Future<Either<Failure, String>> schoolFromPlace(Place place) async {
    resolved.add(place);
    return const Right('school-uuid');
  }

  @override
  Future<Either<Failure, GeoPoint?>> homeLocation() async => const Right(null);

  @override
  Future<Either<Failure, List<Child>>> getKids() => throw UnimplementedError();

  @override
  Future<Either<Failure, String>> saveKid(ChildDraft draft) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> deleteKid(String id) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> assignSchool({
    required Set<String> kidIds,
    required String schoolId,
  }) => throw UnimplementedError();
}
