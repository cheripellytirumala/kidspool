import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fpdart/fpdart.dart';
import 'package:kidspool/ask_ride/core/constants/ask_ride_api_constants.dart';
import 'package:kidspool/ask_ride/data/data_sources/remote/ask_ride_remote_data_source.dart';
import 'package:kidspool/ask_ride/data/repositories/ask_ride_repository_impl.dart';
import 'package:kidspool/ask_ride/data/data_sources/local/ask_ride_local_data_source.dart';
import 'package:kidspool/ask_ride/domain/entities/ask_ride_kid.dart';
import 'package:kidspool/ask_ride/domain/entities/ride_request_result.dart';
import 'package:kidspool/ask_ride/domain/entities/ride_time.dart';
import 'package:kidspool/ask_ride/domain/entities/saved_place.dart';
import 'package:kidspool/ask_ride/domain/repositories/ask_ride_repository.dart';
import 'package:kidspool/ask_ride/domain/usecases/add_saved_place.dart';
import 'package:kidspool/ask_ride/domain/usecases/get_ride_options.dart';
import 'package:kidspool/ask_ride/domain/usecases/search_drop_off_places.dart';
import 'package:kidspool/ask_ride/presentation/providers/ask_ride_provider.dart';
import 'package:kidspool/ask_ride/presentation/providers/drop_off_search_provider.dart';
import 'package:kidspool/ask_ride/presentation/widgets/ask_ride_sheet.dart';
import 'package:kidspool/ask_ride/presentation/widgets/drop_off_picker_sheet.dart';
import 'package:kidspool/ask_ride/presentation/widgets/place_picker_sheet.dart';
import 'package:kidspool/add_kids/domain/repositories/kids_repository.dart';
import 'package:kidspool/common/core/error/exceptions.dart';
import 'package:kidspool/common/core/error/failures.dart';
import 'package:kidspool/common/core/network/api_client.dart';
import 'package:kidspool/common/core/services/time_zone_service.dart';
import 'package:kidspool/common/domain/entities/picked_address.dart';
import 'package:kidspool/common/domain/entities/place_search_result.dart';
import 'package:kidspool/common/domain/entities/place_suggestion.dart';
import 'package:kidspool/common/domain/repositories/places_repository.dart';

const _home = SavedPlace(
  id: 'a1',
  name: 'Home · 24 Maple St',
  address: '24 Maple St, Oakland',
  kind: PlaceKind.home,
  detail: 'default',
  latitude: 37.8044,
  longitude: -122.2712,
);

const _lincoln = SavedPlace(
  id: 's1',
  name: 'Lincoln Elementary',
  address: 'Lincoln Elementary',
  kind: PlaceKind.school,
);

const _swim = SavedPlace(
  id: 'custom:ChIJswim',
  name: 'Bluewave Swim Club',
  address: '500 Lake Ave, Oakland · 94610',
  kind: PlaceKind.custom,
  latitude: 37.81,
  longitude: -122.25,
  addressLine1: '500 Lake Ave',
  city: 'Oakland',
  state: 'CA',
  zip: '94610',
);

final _baseParams = CreateRideParams(
  kidIds: const ['k1'],
  pickupDate: DateTime(2026, 11, 5),
  pickupTime: '08:30',
  timeZone: 'America/Los_Angeles',
  pickupAddressId: 'a1',
  note: '',
);

const _swimAddress = DropOffAddress(
  label: 'Bluewave Swim Club',
  addressLine1: '500 Lake Ave',
  city: 'Oakland',
  state: 'CA',
  zip: '94610',
  latitude: 37.81,
  longitude: -122.25,
);

CreateRideParams _withDropoff(DropOffAddress? d) => CreateRideParams(
  kidIds: _baseParams.kidIds,
  pickupDate: _baseParams.pickupDate,
  pickupTime: _baseParams.pickupTime,
  timeZone: _baseParams.timeZone,
  pickupAddressId: _baseParams.pickupAddressId,
  note: _baseParams.note,
  dropoff: d,
);

void main() {
  group('create_ride_request params', () {
    test('school ride: exactly the old params, no dropoffAddress', () {
      expect(AskRideRemoteDataSourceImpl.createRideParams(_baseParams), {
        'kidIds': ['k1'],
        'pickupDate': '2026-11-05',
        'pickupTime': '08:30',
        'timeZone': 'America/Los_Angeles',
        'pickupAddressId': 'a1',
        'note': null,
        'repeatSchoolDays': false,
        'requireApproval': false,
      });
    });

    test('custom drop-off adds dropoffAddress (pickupAddress shape)', () {
      final params = AskRideRemoteDataSourceImpl.createRideParams(
        _withDropoff(_swimAddress),
      );
      expect(params['dropoffAddress'], {
        'label': 'Bluewave Swim Club',
        'addressLine1': '500 Lake Ave',
        'city': 'Oakland',
        'state': 'CA',
        'zip': '94610',
        'latitude': 37.81,
        'longitude': -122.25,
      });
      expect(params['pickupAddressId'], 'a1');
    });

    test('empty parts are null and long values are trimmed', () {
      final json = AskRideRemoteDataSourceImpl.dropoffJson(
        DropOffAddress(label: 'x' * 80, latitude: 1, longitude: 2),
      );
      expect((json['label'] as String).length, 60);
      expect(json['addressLine1'], isNull);
      expect(json['city'], isNull);
      expect(json['zip'], isNull);
    });
  });

  group('create_ride_request errors', () {
    const missing = ServerException(
      'Could not find the function public.create_ride_request(...)',
      404,
      null,
      {'code': 'PGRST202'},
    );

    test('missing function with a drop-off → friendly message', () {
      final e = AskRideRemoteDataSourceImpl.mapCreateError(
        missing,
        withDropoff: true,
      );
      expect(e.message, AskRideApiConstants.dropoffNotSupportedMessage);
      expect(
        e.message,
        "Drop-off at any place isn't set up on the server yet. "
        "Pick your kid's school for now.",
      );
      expect(e.code, AskRideApiConstants.dropoffNotSupported);
    });

    test('school ride errors pass through unchanged', () {
      final e = AskRideRemoteDataSourceImpl.mapCreateError(
        missing,
        withDropoff: false,
      );
      expect(identical(e, missing), isTrue);
    });

    test('same_place → same-place message', () {
      final e = AskRideRemoteDataSourceImpl.mapCreateError(
        const ServerException('x', 400, 'same_place'),
        withDropoff: true,
      );
      expect(e.message, AskRideApiConstants.samePlaceMessage);
    });

    test('through the repository: failure, no crash', () async {
      final api = _FakeApi(
        error: const ServerException('nope', 404, null, {'code': 'PGRST202'}),
      );
      final repo = AskRideRepositoryImpl(
        remoteDataSource: AskRideRemoteDataSourceImpl(api),
        localDataSource: _NoLocal(),
        kidsRepository: _NoKids(),
      );
      final result = await repo.createRideRequest(_withDropoff(_swimAddress));
      expect(
        result.getLeft().toNullable()?.message,
        AskRideApiConstants.dropoffNotSupportedMessage,
      );
      expect(api.lastParams?['dropoffAddress'], isNotNull);
    });
  });

  group('AskRideProvider validation', () {
    late _FakeRepo repo;
    late AskRideProvider provider;

    Future<void> setUpProvider({String? schoolId = 's1'}) async {
      repo = _FakeRepo(
        kids: [
          AskRideKid(
            id: 'k1',
            name: 'Emma',
            schoolId: schoolId,
            schoolName: schoolId == null ? null : 'Lincoln Elementary',
          ),
        ],
        places: const [_home],
      );
      provider = AskRideProvider(
        getRideOptions: GetRideOptions(repo),
        addSavedPlace: AddSavedPlace(repo),
        repository: repo,
        timeZone: _FixedTimeZone(),
      );
      await provider.load();
      provider.setOnce(
        date: DateTime.now().add(const Duration(days: 3)),
        time: const RideTime(8, 30),
      );
    }

    test('school drop-off is valid and sends no dropoffAddress', () async {
      await setUpProvider();
      expect(provider.draft.dropOff, _lincoln);
      expect(provider.validationError, isNull);
      expect(await provider.submit(), isNull);
      expect(repo.sent.single.dropoff, isNull);
    });

    test('custom drop-off is valid and sends dropoffAddress', () async {
      await setUpProvider();
      provider.setDropOff(_swim);
      expect(provider.validationError, isNull);
      expect(await provider.submit(), isNull);
      expect(repo.sent.single.dropoff, _swimAddress);
    });

    test('custom drop-off works for a kid without a school', () async {
      await setUpProvider(schoolId: null);
      expect(provider.draft.dropOff, isNull);
      expect(provider.validationError, 'Choose where to drop off.');
      provider.setDropOff(_swim);
      expect(provider.validationError, isNull);
    });

    test('custom drop-off at the pick-up is rejected', () async {
      await setUpProvider();
      provider.setDropOff(
        const SavedPlace(
          id: 'custom:ChIJhome',
          name: '24 Maple St',
          address: '24 Maple St, Oakland',
          kind: PlaceKind.custom,
          latitude: 37.80442,
          longitude: -122.27121,
        ),
      );
      expect(provider.validationError, AskRideApiConstants.samePlaceMessage);
    });

    test('same place by id is rejected', () {
      expect(AskRideProvider.isSamePlace(_home, _home), isTrue);
      expect(AskRideProvider.isSamePlace(_home, _swim), isFalse);
      expect(AskRideProvider.isSamePlace(_home, _lincoln), isFalse);
    });

    test('toggling kids keeps a custom drop-off', () async {
      await setUpProvider();
      provider.setDropOff(_swim);
      provider.toggleKid('k1');
      provider.toggleKid('k1');
      expect(provider.draft.dropOff, _swim);
    });

    test('drop-off search is biased near the pick-up', () async {
      await setUpProvider();
      expect(provider.searchNear, _home);
    });
  });

  group('SearchDropOffPlaces', () {
    test(
      'no includedType, biased near the pick-up, mapped to custom',
      () async {
        final places = _FakePlaces();
        final result = await SearchDropOffPlaces(places)(
          const SearchDropOffPlacesParams(
            query: '  500  Lake Ave ',
            nearLatitude: 1,
            nearLongitude: 2,
          ),
        );
        expect(places.query, '500 Lake Ave');
        expect(places.includedType, isNull);
        expect(places.near, (1.0, 2.0));
        final p = result.getRight().toNullable()!.single;
        expect(p.kind, PlaceKind.custom);
        expect(p.name, 'Bluewave Swim Club');
        expect(p.address, '500 Lake Ave, Oakland · 94610');
        expect(p.addressLine1, '500 Lake Ave');
        expect(p.zip, '94610');
        expect(AskRideProvider.dropOffAddress(p), _swimAddress);
      },
    );

    test('empty query → no search', () async {
      final places = _FakePlaces();
      final result = await SearchDropOffPlaces(places)(
        const SearchDropOffPlacesParams(query: '   '),
      );
      expect(result.getRight().toNullable(), isEmpty);
      expect(places.query, isNull);
    });

    test('provider debounces and clears on an empty query', () async {
      final places = _FakePlaces();
      final search = DropOffSearchProvider(
        searchPlaces: SearchDropOffPlaces(places),
      );
      expect(search.isIdle, isTrue);
      search.setQuery('9461');
      search.setQuery('94610');
      await Future<void>.delayed(
        DropOffSearchProvider.debounce + const Duration(milliseconds: 50),
      );
      expect(places.calls, 1);
      expect(places.query, '94610');
      expect(search.results, hasLength(1));
      search.setQuery('');
      expect(search.results, isEmpty);
      search.dispose();
    });
  });

  testWidgets('Drop off at sheet: Schools and Search location tabs', (
    tester,
  ) async {
    final places = _FakePlaces();
    PlacePickerResult? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await showAskRideSheet<PlacePickerResult>(
                  context,
                  ChangeNotifierProvider<DropOffSearchProvider>(
                    create: (_) => DropOffSearchProvider(
                      searchPlaces: SearchDropOffPlaces(places),
                    ),
                    child: const DropOffPickerSheet(
                      schools: [_lincoln],
                      selected: _lincoln,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Drop off at'), findsOneWidget);
    expect(find.text('Lincoln Elementary'), findsWidgets);

    await tester.tap(find.text('Search location'));
    await tester.pumpAndSettle();
    expect(find.text('Search a place, address or zip code'), findsOneWidget);
    expect(places.calls, 0);

    await tester.enterText(find.byType(TextField), 'swim');
    await tester.pump(DropOffSearchProvider.debounce);
    await tester.pumpAndSettle();
    expect(find.text('Bluewave Swim Club'), findsOneWidget);
    expect(find.text('500 Lake Ave, Oakland · 94610'), findsOneWidget);

    await tester.tap(find.text('Bluewave Swim Club'));
    await tester.pumpAndSettle();
    expect(picked, isA<CustomPlacePicked>());
    expect((picked! as CustomPlacePicked).place.isCustom, isTrue);
    expect(tester.takeException(), isNull);
  });
}

class _FakeApi extends ApiClient {
  _FakeApi({this.error}) : super(Dio());

  final AppException? error;
  Map<String, dynamic>? lastParams;

  @override
  Future<T> rpc<T>(
    String name, {
    required ResponseParser<T> parser,
    Map<String, dynamic>? params,
    bool skipAuth = false,
  }) async {
    lastParams = params;
    if (error != null) throw error!;
    return parser({'requests': [], 'eligibleDriversCount': 0});
  }
}

class _NoLocal implements AskRideLocalDataSource {}

class _NoKids implements KidsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedTimeZone extends TimeZoneService {
  @override
  Future<String> current() async => 'America/Los_Angeles';
}

class _FakeRepo implements AskRideRepository {
  _FakeRepo({required this.kids, required this.places});

  final List<AskRideKid> kids;
  final List<SavedPlace> places;
  final List<CreateRideParams> sent = [];

  @override
  Future<Either<Failure, List<AskRideKid>>> getKids() async => Right(kids);

  @override
  Future<Either<Failure, List<SavedPlace>>> getSavedPlaces() async =>
      Right(places);

  @override
  Future<Either<Failure, List<SavedPlace>>> addSavedPlace(
    PickedAddress address, {
    required String label,
  }) async => Right(places);

  @override
  Future<Either<Failure, RideRequestResult>> createRideRequest(
    CreateRideParams params,
  ) async {
    sent.add(params);
    return const Right(
      RideRequestResult(requestIds: ['r1'], eligibleDriversCount: 2),
    );
  }
}

class _FakePlaces implements PlacesRepository {
  String? query;
  String? includedType;
  (double?, double?)? near;
  int calls = 0;

  @override
  Future<bool> isSearchConfigured() async => true;

  @override
  Future<Either<Failure, List<PlaceSearchResult>>> searchText(
    String query, {
    String? includedType,
    double? nearLatitude,
    double? nearLongitude,
    double radiusMeters = 5000,
  }) async {
    calls++;
    this.query = query;
    this.includedType = includedType;
    near = (nearLatitude, nearLongitude);
    return const Right([
      PlaceSearchResult(
        placeId: 'ChIJswim',
        name: 'Bluewave Swim Club',
        latitude: 37.81,
        longitude: -122.25,
        formattedAddress: '500 Lake Ave, Oakland, CA 94610, USA',
        shortAddress: '500 Lake Ave, Oakland',
        street: '500 Lake Ave',
        city: 'Oakland',
        stateCode: 'CA',
        zip: '94610',
      ),
    ]);
  }

  @override
  Future<Either<Failure, List<PlaceSuggestion>>> search(
    String query, {
    required String sessionToken,
    double? nearLatitude,
    double? nearLongitude,
  }) async => const Right([]);

  @override
  Future<Either<Failure, PickedAddress>> details(
    String placeId, {
    required String sessionToken,
  }) async => const Left(UnexpectedFailure());

  @override
  Future<Either<Failure, PickedAddress>> addressAt(
    double latitude,
    double longitude,
  ) async => const Left(UnexpectedFailure());

  @override
  Future<Either<Failure, PickedAddress>> currentLocation() async =>
      const Left(UnexpectedFailure());
}
