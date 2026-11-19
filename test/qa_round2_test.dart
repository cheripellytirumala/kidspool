import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/add_kids/data/data_sources/remote/kids_remote_data_source.dart';
import 'package:kidspool/add_kids/domain/entities/place.dart';
import 'package:kidspool/common/core/network/dio_error_mapper.dart';

Place _place(String name, {String address = '', String city = ''}) => Place(
  id: 'p1',
  name: name,
  category: PlaceCategory.school,
  addressLine: address,
  city: city,
);

String _map(Map<String, dynamic> body, int status) {
  final options = RequestOptions(path: '/rpc/x');
  return DioErrorMapper.map(
    DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: options,
        statusCode: status,
        data: body,
      ),
    ),
  ).message;
}

void main() {
  group('school name sent to school_from_place', () {
    test('a one-letter name gets the address added', () {
      expect(
        KidsRemoteDataSourceImpl.schoolName(
          _place('Y', address: '12 Oak St', city: 'Austin'),
        ),
        'Y · 12 Oak St, Austin',
      );
    });

    test('normal names are kept, long ones cut to 120', () {
      expect(
        KidsRemoteDataSourceImpl.schoolName(_place(' Lincoln Elementary ')),
        'Lincoln Elementary',
      );
      final long = KidsRemoteDataSourceImpl.schoolName(_place('A' * 200));
      expect(long.length, 120);
    });

    test('no name and no address still saves', () {
      expect(KidsRemoteDataSourceImpl.schoolName(_place('')), 'School');
    });
  });

  test('raw Postgres errors are never shown', () {
    final message = _map({
      'code': '23514',
      'message':
          'new row for relation "schools" violates check constraint '
          '"schools_name_check"',
    }, 400);
    expect(message, isNot(contains('relation')));
    expect(message, 'Please check the details you entered.');
  });
}
