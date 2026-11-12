import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/add_kids/data/data_sources/remote/kids_remote_data_source.dart';
import 'package:kidspool/add_kids/domain/entities/place.dart';
import 'package:kidspool/common/core/network/api_client.dart';

/// The real `get_schools('doon public school')` reply.
const _body =
    '[{"id": "5fa458ab-d461-4141-b4a9-c5b52fce640b", "zip": "641018", '
    '"city": "Ramanathapuram", "name": "Doon Public School", "state": "TN", '
    '"latitude": 10.9956443, "longitude": 76.9781608, '
    '"addressLine": "1 Trichy Rd"}, '
    '{"id": "ee5be54e-f43a-4c19-8032-da6bb54d6990", "zip": "110063", '
    '"city": "New Delhi", "name": "Doon Public School", "state": "DL", '
    '"latitude": 28.6684038, "longitude": 77.1044576, '
    '"addressLine": "Doon Public School"}]';

class _Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    _body,
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  test('get_schools rows become saved school places', () async {
    final remote = KidsRemoteDataSourceImpl(
      ApiClient(Dio(BaseOptions(baseUrl: 'https://x.test/'))
        ..httpClientAdapter = _Adapter()),
    );
    final places = await remote.searchSavedPlaces(
      PlaceKind.school,
      'doon public school',
    );
    expect(places.map((p) => p.city), ['Ramanathapuram', 'New Delhi']);
    expect(places.first.isSaved, isTrue);
    expect(places.first.latitude, 10.9956443);
  });
}
