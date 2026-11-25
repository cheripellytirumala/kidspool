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
    this.photoUrl,
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

  /// Short-lived link to the photo (only right after saving).
  final String? photoUrl;

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
    '$kidSeats member ${kidSeats == 1 ? 'seat' : 'seats'} free',
    if (hasBooster) 'booster',
  ].join(' · ');

  /// Colours offered on "Your vehicle" (name, swatch ARGB).
  static const List<(String, int)> colors = [
    ('White', 0xFFFFFFFF),
    ('Black', 0xFF111111),
    ('Silver', 0xFFC0C4C8),
    ('Grey', 0xFF7A7F85),
    ('Red', 0xFFC8282D),
    ('Blue', 0xFF2456B8),
    ('Brown', 0xFF7A4E2D),
    ('Beige', 0xFFD9C7A3),
    ('Green', 0xFF2F7A3C),
    ('Yellow', 0xFFF2C230),
    ('Orange', 0xFFE8742A),
    ('Maroon', 0xFF6B1A26),
  ];

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
