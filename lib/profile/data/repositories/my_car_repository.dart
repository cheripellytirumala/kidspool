import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/error_handler.dart';
import '../../../common/core/error/failures.dart';
import '../../../common/core/network/api_client.dart';
import '../../domain/entities/my_car.dart';

/// `get_my_car` / `set_my_car`: the parent's car seats and booster.
class MyCarRepository {
  const MyCarRepository(this._api);

  final ApiClient _api;

  /// The saved car, or `null` when none is saved yet.
  Future<Either<Failure, MyCar?>> get() => ErrorHandler.guard(
    tag: 'Profile.getMyCar',
    () => _api.rpc('get_my_car', parser: parse),
  );

  /// Seats and booster only (Profile › My car).
  Future<Either<Failure, MyCar?>> save({
    required int carSeats,
    required bool hasBooster,
  }) => ErrorHandler.guard(
    tag: 'Profile.setMyCar',
    () => _api.rpc(
      'set_my_car',
      params: {'carSeats': carSeats, 'hasBooster': hasBooster},
      parser: parse,
    ),
  );

  /// Everything on "Your vehicle", with an optional new photo
  /// (`save-vehicle` Edge Function).
  Future<Either<Failure, MyCar?>> saveVehicle({
    required String model,
    required String plateNumber,
    required int carSeats,
    required int kidSeats,
    required bool hasBooster,
    String? color,
    int? year,
    String? photoPath,
  }) => ErrorHandler.guard(
    tag: 'Profile.saveVehicle',
    () async => _api.invokeFunction(
      'save-vehicle',
      data: FormData.fromMap({
        'model': model,
        'plateNumber': plateNumber,
        'carSeats': '$carSeats',
        'kidSeats': '$kidSeats',
        'boosterSeat': '$hasBooster',
        'color': ?color,
        if (year != null) 'year': '$year',
        if (photoPath != null)
          'vehiclePhoto': await MultipartFile.fromFile(photoPath),
      }),
      parser: parse,
    ),
  );

  static MyCar? parse(dynamic json) {
    if (json is! Map) return null;
    final seats = json['carSeats'];
    if (seats is! num) return null;
    String? text(String k) =>
        json[k] is String && (json[k] as String).trim().isNotEmpty
        ? (json[k] as String).trim()
        : null;
    final kid = json['kidSeats'];
    final year = json['year'];
    return MyCar(
      carSeats: seats.toInt(),
      kidSeats: kid is num ? kid.toInt() : null,
      hasBooster: json['hasBooster'] == true,
      model: text('model'),
      color: text('color'),
      year: year is num ? year.toInt() : null,
      plateNumber: text('plateNumber'),
      hasPhoto: json['hasPhoto'] == true,
    );
  }
}
