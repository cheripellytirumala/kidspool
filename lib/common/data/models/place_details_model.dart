import '../../core/error/exceptions.dart';
import '../../core/utils/json_parser.dart';
import '../../domain/entities/picked_address.dart';

/// `GET places/{id}` response (Places API New) → [PickedAddress].
class PlaceDetailsModel {
  const PlaceDetailsModel(this._json);

  final Map<String, dynamic> _json;

  PickedAddress toEntity() {
    final location = _json['location'];
    if (location is! Map) {
      throw const ParsingException('Place has no location.');
    }
    final loc = Map<String, dynamic>.from(location);
    final lat = loc.readDouble('latitude');
    final lng = loc.readDouble('longitude');
    if (lat == null || lng == null) {
      throw const ParsingException('Place has no location.');
    }

    final components = _json.readList('addressComponents', (c) => c);
    String part(String type, {bool short = false}) {
      for (final c in components) {
        final types = c['types'];
        if (types is List && types.contains(type)) {
          return c.readString(short ? 'shortText' : 'longText') ?? '';
        }
      }
      return '';
    }

    final street = [
      part('street_number'),
      part('route'),
    ].where((p) => p.isNotEmpty).join(' ');
    final city = [
      part('locality'),
      part('postal_town'),
      part('sublocality'),
      part('administrative_area_level_2'),
    ].firstWhere((p) => p.isNotEmpty, orElse: () => '');
    final formatted = _json.readString('formattedAddress') ?? '';
    final displayName = _json['displayName'];
    final name = displayName is Map
        ? Map<String, dynamic>.from(displayName).readString('text')
        : null;

    return PickedAddress(
      latitude: lat,
      longitude: lng,
      // Places without a street number (e.g. schools) fall back to the name
      // or the first line of the formatted address.
      street: street.isNotEmpty
          ? street
          : (name ?? formatted.split(',').first).trim(),
      city: city,
      stateCode: part('administrative_area_level_1', short: true),
      zip: part('postal_code'),
      formatted: formatted,
      name: name,
    );
  }
}
