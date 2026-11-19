import 'package:equatable/equatable.dart';

/// The driving parent's car ("Your vehicle", Profile › My car).
class MyCar extends Equatable {
  const MyCar({
    required this.carSeats,
    int? kidSeats,
    this.hasBooster = false,
    this.model,
    this.color,
    this.year,
    this.plateNumber,
    this.hasPhoto = false,
  }) : _kidSeats = kidSeats;

  /// All seats, driver included: 5 = a 5-seater.
  final int carSeats;
  final int? _kidSeats;
  final bool hasBooster;

  /// "Honda Odyssey".
  final String? model;

  /// "White".
  final String? color;
  final int? year;
  final String? plateNumber;
  final bool hasPhoto;

  /// Seats free for kids: as saved, else all but the driver's.
  int get kidSeats => _kidSeats ?? carSeats - 1;

  /// "White Honda Odyssey".
  String get title => [
    color,
    model,
  ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');

  /// "7-seater · 3 kid seats free · booster".
  String get summary => [
    '$carSeats-seater',
    '$kidSeats kid ${kidSeats == 1 ? 'seat' : 'seats'} free',
    if (hasBooster) 'booster',
  ].join(' · ');

  /// Car sizes offered.
  static const List<int> sizes = [4, 5, 6, 7, 8];

  @override
  List<Object?> get props => [
    carSeats,
    kidSeats,
    hasBooster,
    model,
    color,
    year,
    plateNumber,
    hasPhoto,
  ];
}
