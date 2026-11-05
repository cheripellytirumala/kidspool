import '../../core/utils/json_parser.dart';

/// `addressComponents` of a Places API (New) place, split into the parts
/// the app saves.
class AddressComponents {
  AddressComponents(Map<String, dynamic> place)
    : _components = place.readList('addressComponents', (c) => c);

  final List<Map<String, dynamic>> _components;

  String part(String type, {bool short = false}) {
    for (final c in _components) {
      final types = c['types'];
      if (types is List && types.contains(type)) {
        return c.readString(short ? 'shortText' : 'longText') ?? '';
      }
    }
    return '';
  }

  /// Street number + route (`24 Maple St`), short route names when given.
  String get street => [
    part('street_number'),
    part('route', short: true),
  ].where((p) => p.isNotEmpty).join(' ');

  String get city => [
    part('locality'),
    part('postal_town'),
    part('sublocality'),
    part('administrative_area_level_2'),
  ].firstWhere((p) => p.isNotEmpty, orElse: () => '');

  /// Two-letter state, e.g. `CA`.
  String get stateCode => part('administrative_area_level_1', short: true);

  String get zip => part('postal_code');
}
