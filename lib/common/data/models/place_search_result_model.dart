import '../../core/error/exceptions.dart';
import '../../core/utils/json_parser.dart';
import '../../domain/entities/place_search_result.dart';
import 'address_components.dart';

/// `POST places:searchText` response (Places API New) → results.
abstract final class PlaceSearchResultModel {
  /// Parses `{places: [...]}`. Places without an id, name or location are
  /// skipped; a missing `places` key means no results.
  static List<PlaceSearchResult> listFromJson(Map<String, dynamic> json) {
    final places = json['places'];
    if (places == null) return const [];
    if (places is! List) throw const ParsingException();
    return places
        .whereType<Map>()
        .map((p) => fromJson(Map<String, dynamic>.from(p)))
        .whereType<PlaceSearchResult>()
        .toList(growable: false);
  }

  static PlaceSearchResult? fromJson(Map<String, dynamic> json) {
    final id = json.readString('id');
    final name = _text(json['displayName']);
    final location = json['location'];
    if (id == null || id.isEmpty || name == null || name.isEmpty) return null;
    if (location is! Map) return null;
    final loc = Map<String, dynamic>.from(location);
    final lat = loc.readDouble('latitude');
    final lng = loc.readDouble('longitude');
    if (lat == null || lng == null) return null;

    final parts = AddressComponents(json);
    final formatted = json.readString('formattedAddress') ?? '';
    return PlaceSearchResult(
      placeId: id,
      name: name,
      latitude: lat,
      longitude: lng,
      formattedAddress: formatted,
      shortAddress: json.readString('shortFormattedAddress') ?? '',
      // Some places have no street number: fall back to the first line of
      // the formatted address.
      street: parts.street.isNotEmpty
          ? parts.street
          : (formatted.contains(',') ? formatted.split(',').first.trim() : ''),
      city: parts.city,
      stateCode: parts.stateCode,
      zip: parts.zip,
      primaryType: json.readString('primaryType'),
    );
  }

  static String? _text(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v).readString('text') : null;
}
