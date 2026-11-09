import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:kidspool/common/core/error/exceptions.dart';
import 'package:kidspool/common/core/error/failures.dart';
import 'package:kidspool/common/core/network/api_client.dart';
import 'package:kidspool/home/core/constants/home_api_constants.dart';
import 'package:kidspool/home/data/data_sources/local/home_local_data_source.dart';
import 'package:kidspool/home/data/data_sources/remote/home_remote_data_source.dart';
import 'package:kidspool/home/data/models/family_model.dart';
import 'package:kidspool/home/data/repositories/home_repository_impl.dart';
import 'package:kidspool/home/domain/entities/family.dart';
import 'package:kidspool/home/domain/usecases/get_families_near_me.dart';
import 'package:kidspool/home/presentation/providers/families_near_you_provider.dart';
import 'package:kidspool/messages/domain/entities/ride_chat.dart';
import 'package:kidspool/messages/domain/usecases/send_ride_message.dart';

/// Answers `rpc` calls from [handlers] (name → JSON or a thrown exception).
class _FakeApiClient extends ApiClient {
  _FakeApiClient(this.handlers) : super(Dio());

  final Map<String, Object? Function(Map<String, dynamic>? params)> handlers;
  final List<(String, Map<String, dynamic>?)> calls = [];

  @override
  Future<T> rpc<T>(
    String name, {
    required ResponseParser<T> parser,
    Map<String, dynamic>? params,
    bool skipAuth = false,
  }) async {
    calls.add((name, params));
    final handler = handlers[name];
    if (handler == null) throw const ServerException('no handler', 500);
    return parser(handler(params));
  }
}

class _FakeLocal implements HomeLocalDataSource {
  @override
  DateTime? getNotificationsSeenAt() => null;

  @override
  Future<void> setNotificationsSeenAt(DateTime at) async {}
}

Map<String, dynamic> _row({
  String id = 'p1',
  String firstName = 'Jen',
  String lastInitial = 'P',
  String initials = 'JP',
  bool givesRides = true,
  List<Map<String, dynamic>>? kids,
  Object? distanceMiles = 0.4,
}) => {
  'id': id,
  'firstName': firstName,
  'lastInitial': lastInitial,
  'initials': initials,
  'givesRides': givesRides,
  'kids':
      kids ??
      [
        {
          'firstName': 'Mia',
          'schoolId': 's1',
          'schoolName': 'Lincoln Elementary',
        },
      ],
  'distanceMiles': distanceMiles,
};

Family _family(
  String id, {
  required List<(String, String)> schools,
  double? miles,
  bool givesRides = false,
}) => Family(
  id: id,
  parentName: id,
  initials: id.substring(0, 1).toUpperCase(),
  kids: [
    for (final (schoolId, name) in schools)
      FamilyKid(firstName: 'Kid', schoolId: schoolId, schoolName: name),
  ],
  distanceMiles: miles,
  givesRides: givesRides,
);

(HomeRepositoryImpl, _FakeApiClient) _repo(
  Map<String, Object? Function(Map<String, dynamic>? params)> handlers,
) {
  final api = _FakeApiClient(handlers);
  return (
    HomeRepositoryImpl(
      remoteDataSource: HomeRemoteDataSourceImpl(api),
      localDataSource: _FakeLocal(),
    ),
    api,
  );
}

void main() {
  group('FamilyModel.fromJson', () {
    test('maps name, initials, kids, distance and givesRides', () {
      final f = FamilyModel.fromJson(
        _row(
          kids: [
            {
              'firstName': 'Mia',
              'schoolId': 's1',
              'schoolName': 'Lincoln Elementary',
            },
            {
              'firstName': 'Leo',
              'schoolId': 's2',
              'schoolName': 'Oak Middle School',
            },
          ],
        ),
      )!;
      expect(f.id, 'p1');
      expect(f.parentName, 'Jen P.');
      expect(f.initials, 'JP');
      expect(f.givesRides, isTrue);
      expect(f.needsRides, isFalse);
      expect(f.kids.map((k) => k.firstName), ['Mia', 'Leo']);
      expect(f.placeIds, {'s1', 's2'});
      expect(f.childLabel, 'Mia & Leo');
      expect(f.placeName, 'Lincoln Elementary, Oak Middle School');
      expect(f.shortPlaceName, 'Lincoln');
      expect(f.distanceMiles, 0.4);
      expect(f.distanceLabel, '0.4 mi');
      expect(
        f.detailLabel,
        'Mia & Leo · Lincoln Elementary, Oak Middle School · 0.4 mi',
      );
      expect(f.compactLabel, 'Lincoln · 0.4 mi');
    });

    test('formats whole and integer distances with one decimal', () {
      expect(
        FamilyModel.fromJson(_row(distanceMiles: 2))!.distanceLabel,
        '2.0 mi',
      );
      expect(
        FamilyModel.fromJson(_row(distanceMiles: '1.26'))!.distanceLabel,
        '1.3 mi',
      );
    });

    test('null distance is omitted from the labels', () {
      final f = FamilyModel.fromJson(_row(distanceMiles: null))!;
      expect(f.distanceMiles, isNull);
      expect(f.distanceLabel, isNull);
      expect(f.detailLabel, 'Mia · Lincoln Elementary');
      expect(f.compactLabel, 'Lincoln');
    });

    test('needs rides when not a driver; falls back to derived initials', () {
      final f = FamilyModel.fromJson(
        _row(givesRides: false, initials: '', lastInitial: ''),
      )!;
      expect(f.givesRides, isFalse);
      expect(f.needsRides, isTrue);
      expect(f.parentName, 'Jen');
      expect(f.initials, 'J');
    });

    test('skips rows without an id and kids without a school', () {
      expect(FamilyModel.fromJson(_row(id: '')), isNull);
      final f = FamilyModel.fromJson(
        _row(
          kids: [
            {'firstName': 'Mia', 'schoolId': null, 'schoolName': 'x'},
          ],
        ),
      )!;
      expect(f.kids, isEmpty);
      expect(f.childLabel, '');
    });

    test('parseFamilies keeps order and rejects non-lists', () {
      final list = HomeRemoteDataSourceImpl.parseFamilies([
        _row(id: 'a'),
        'junk',
        _row(id: 'b', firstName: 'David', lastInitial: 'C'),
      ]);
      expect(list.map((f) => f.parentName), ['Jen P.', 'David C.']);
      expect(
        () => HomeRemoteDataSourceImpl.parseFamilies({}),
        throwsA(isA<ParsingException>()),
      );
    });

    test('three or more kids read "A, B & C"', () {
      final f = FamilyModel.fromJson(
        _row(
          kids: [
            for (final n in ['Mia', 'Leo', 'Ava'])
              {'firstName': n, 'schoolId': 's1', 'schoolName': 'Lincoln'},
          ],
        ),
      )!;
      expect(f.childLabel, 'Mia, Leo & Ava');
      expect(f.placeName, 'Lincoln');
    });
  });

  group('HomeRepositoryImpl.getFamiliesNearMe', () {
    test('sends params named like the SQL arguments', () async {
      final (repo, api) = _repo({
        HomeApiConstants.getFamiliesNearMe: (_) => [_row()],
      });
      final result = await repo.getFamiliesNearMe(schoolId: 's1');
      expect(result.isRight(), isTrue);
      expect(api.calls.single.$2, {'schoolId': 's1', 'radiusMiles': 10.0});

      await repo.getFamiliesNearMe();
      expect(api.calls.last.$2, {'radiusMiles': 10.0});
    });

    test('empty list asks get_my_kids whether a kid has a school', () async {
      var kids = <Map<String, dynamic>>[
        {'id': 'k1', 'firstName': 'Emma', 'school': null},
      ];
      final (repo, _) = _repo({
        HomeApiConstants.getFamiliesNearMe: (_) => <Object>[],
        HomeApiConstants.getMyKids: (_) => kids,
      });
      var data = (await repo.getFamiliesNearMe()).getOrElse((_) => throw 0);
      expect(data.families, isEmpty);
      expect(data.hasSchool, isFalse);

      kids = [
        {
          'id': 'k1',
          'school': {'id': 's1', 'name': 'Lincoln'},
        },
      ];
      data = (await repo.getFamiliesNearMe()).getOrElse((_) => throw 0);
      expect(data.hasSchool, isTrue);
    });

    test(
      'missing RPC (404 / PGRST202) fails once, then without a call',
      () async {
        final (repo, api) = _repo({
          HomeApiConstants.getFamiliesNearMe: (_) =>
              throw const ServerException(
                'Could not find the function',
                404,
                null,
                {'code': 'PGRST202'},
              ),
        });
        final first = await repo.getFamiliesNearMe();
        final failure = first.getLeft().toNullable()!;
        expect(failure.code, HomeApiConstants.familiesNearMeMissing);
        expect(
          failure.message,
          'Families near you isn’t set up on the server yet.',
        );

        final second = await repo.getFamiliesNearMe();
        expect(second.getLeft().toNullable()?.code, failure.code);
        expect(api.calls, hasLength(1));
      },
    );

    test('other server errors keep retrying with a friendly message', () async {
      final (repo, api) = _repo({
        HomeApiConstants.getFamiliesNearMe: (_) =>
            throw const ServerException('boom', 500, 'PT500'),
      });
      final failure = (await repo.getFamiliesNearMe()).getLeft().toNullable()!;
      expect(failure.code, isNot(HomeApiConstants.familiesNearMeMissing));
      expect(
        failure.message,
        "Couldn't load families near you. Pull to refresh.",
      );
      await repo.getFamiliesNearMe();
      expect(api.calls, hasLength(2));
    });
  });

  group('FamiliesNearYouProvider', () {
    FamiliesNearYouProvider provider(
      Future<Either<Failure, FamiliesNearMe>> Function() answer,
    ) => FamiliesNearYouProvider(
      getFamiliesNearMe: GetFamiliesNearMe(_FakeRepository(answer)),
    );

    final families = [
      _family(
        'a',
        schools: [('s1', 'Lincoln Elementary')],
        miles: 0.4,
        givesRides: true,
      ),
      _family(
        'b',
        schools: [('s1', 'Lincoln Elementary'), ('s2', 'Oak Middle')],
        miles: 1.0,
      ),
      _family(
        'c',
        schools: [('s2', 'Oak Middle')],
        miles: 1.4,
        givesRides: true,
      ),
      _family('d', schools: [('s1', 'Lincoln Elementary')]),
    ];

    group('sendMessage', () {
      FamiliesNearYouProvider sender(
        _FakeSend send, {
        List<String> requests = const ['r1', 'r2'],
      }) => FamiliesNearYouProvider(
        getFamiliesNearMe: GetFamiliesNearMe(
          _FakeRepository(
            () async =>
                Right(FamiliesNearMe(families: families, hasSchool: true)),
          ),
        ),
        requestIds: () => requests,
        sendRideMessage: send,
      );

      test('delivers the typed text to each selected parent', () async {
        final send = _FakeSend();
        final p = sender(send);
        await p.load();
        p.toggle(families[0]);
        p.toggle(families[2]);
        p.setCustomMessage('  Want to carpool on Fridays?  ');
        final (sent, error) = await p.sendMessage();
        expect(error, isNull);
        expect(sent, 2);
        expect(send.calls.map((c) => (c.requestId, c.driverId, c.body)), [
          ('r1', 'a', 'Want to carpool on Fridays?'),
          ('r1', 'c', 'Want to carpool on Fridays?'),
        ]);
      });

      test('sends the template when nothing is typed', () async {
        final send = _FakeSend();
        final p = sender(send);
        await p.load();
        p.toggle(families[1]);
        await p.sendMessage();
        expect(send.calls.single.body, p.messageTemplate);
        expect(send.calls.single.body, contains('Would you like to share'));
      });

      test('no ride request: nothing is sent and the user is told', () async {
        final send = _FakeSend();
        final p = sender(send, requests: const []);
        await p.load();
        p.toggle(families[0]);
        final (sent, error) = await p.sendMessage();
        expect(sent, 0);
        expect(error, contains('Ask for a ride first'));
        expect(send.calls, isEmpty);
      });

      test('reports the server error when no parent got it', () async {
        final p = sender(_FakeSend(fail: true));
        await p.load();
        p.toggle(families[0]);
        final (sent, error) = await p.sendMessage();
        expect(sent, 0);
        expect(error, 'You can’t message this parent yet.');
      });
    });

    test('chips: All · N, then one per school with its count', () async {
      final p = provider(
        () async => Right(FamiliesNearMe(families: families, hasSchool: true)),
      );
      await p.load();
      expect(p.totalCount, 4);
      expect(p.places.map((pl) => (pl.id, pl.name, p.countFor(pl))), [
        ('s1', 'Lincoln Elementary', 3),
        ('s2', 'Oak Middle', 2),
      ]);
      p.selectPlace('s2');
      expect(p.visibleFamilies.map((f) => f.id), ['b', 'c']);
      expect(p.emptyState, FamiliesEmptyState.none);
    });

    test(
      'Nearby ≤ 1 mi uses distanceMiles; unknown distance is not nearby',
      () async {
        final p = provider(
          () async =>
              Right(FamiliesNearMe(families: families, hasSchool: true)),
        );
        await p.load();
        p
          ..beginSelection(families.first)
          ..setFilter(FamilyFilter.nearby);
        expect(p.visibleFamilies.map((f) => f.id), ['a', 'b']);
        p.setFilter(FamilyFilter.givesRide);
        expect(p.visibleFamilies.map((f) => f.id), ['a', 'c']);
        p.setFilter(FamilyFilter.needsRide);
        expect(p.visibleFamilies.map((f) => f.id), ['b', 'd']);
      },
    );

    test('select mode before load checks every family once loaded', () async {
      final p = provider(
        () async => Right(FamiliesNearMe(families: families, hasSchool: true)),
      )..startInSelectMode();
      await p.load();
      expect(p.selectedCount, 4);
      expect(p.allVisibleSelected, isTrue);
      p.toggleAllVisible();
      expect(p.hasSelection, isFalse);
    });

    test('empty states', () async {
      var answer = Right<Failure, FamiliesNearMe>(
        const FamiliesNearMe(families: [], hasSchool: false),
      );
      final p = provider(() async => answer);
      await p.load();
      expect(p.emptyState, FamiliesEmptyState.noSchool);
      expect(
        p.emptyMessage,
        'Add your kids’ school to see families going to the same places.',
      );

      answer = const Right(FamiliesNearMe(families: [], hasSchool: true));
      await p.load();
      expect(p.emptyState, FamiliesEmptyState.noFamilies);
      expect(p.emptyMessage, 'No families from your kids’ schools nearby yet.');
    });

    test('missing RPC shows the not-set-up message', () async {
      final p = provider(
        () async => const Left(
          ServerFailure(
            'Families near you isn’t set up on the server yet.',
            statusCode: 404,
            code: HomeApiConstants.familiesNearMeMissing,
          ),
        ),
      );
      await p.load();
      expect(p.isUnavailable, isTrue);
      expect(p.emptyState, FamiliesEmptyState.unavailable);
      expect(
        p.emptyMessage,
        'Families near you isn’t set up on the server yet.',
      );
    });
  });
}

class _FakeRepository extends HomeRepositoryImpl {
  _FakeRepository(this._answer)
    : super(
        remoteDataSource: HomeRemoteDataSourceImpl(_FakeApiClient(const {})),
        localDataSource: _FakeLocal(),
      );

  final Future<Either<Failure, FamiliesNearMe>> Function() _answer;

  @override
  Future<Either<Failure, FamiliesNearMe>> getFamiliesNearMe({
    String? schoolId,
    double? radiusMiles,
  }) => _answer();
}

class _FakeSend implements SendRideMessage {
  _FakeSend({this.fail = false});

  final bool fail;
  final List<SendRideMessageParams> calls = [];

  @override
  Future<Either<Failure, ChatMessage>> call(SendRideMessageParams p) async {
    calls.add(p);
    if (fail) {
      return const Left(ServerFailure('You can’t message this parent yet.'));
    }
    return Right(
      ChatMessage(
        id: 'm${calls.length}',
        senderId: 'me',
        body: p.body,
        createdAt: DateTime(2026),
      ),
    );
  }
}
