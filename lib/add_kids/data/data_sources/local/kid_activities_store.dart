import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/place.dart';

/// One activity (soccer, music…) and the kids who go there.
typedef KidActivity = ({Place place, Set<String> childIds});

/// Kids' activities, kept on this device per signed-in parent: the backend
/// has no activities table yet. Read by "Where do your kids go?" and by
/// Ask for a ride (activities as drop-off places).
class KidActivitiesStore {
  KidActivitiesStore(this._preferences, this._userId);

  final SharedPreferences _preferences;
  final String? Function() _userId;

  String? get _key {
    final id = _userId();
    return id == null ? null : 'kid_activities_$id';
  }

  List<KidActivity> read() {
    final key = _key;
    final raw = key == null ? null : _preferences.getString(key);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final item in list.whereType<Map<String, dynamic>>())
          if (_place(item['place']) case final place?)
            (
              place: place,
              childIds: {
                for (final id in (item['childIds'] as List<dynamic>? ?? []))
                  if (id is String) id,
              },
            ),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> write(List<KidActivity> activities) async {
    final key = _key;
    if (key == null) return;
    await _preferences.setString(
      key,
      jsonEncode([
        for (final a in activities)
          {'place': _json(a.place), 'childIds': a.childIds.toList()},
      ]),
    );
  }

  static Map<String, dynamic> _json(Place p) => {
    'id': p.id,
    'name': p.name,
    'category': p.category.name,
    'details': p.details,
    'keywords': p.keywords,
    'googlePlaceId': p.googlePlaceId,
    'latitude': p.latitude,
    'longitude': p.longitude,
    'addressLine': p.addressLine,
    'city': p.city,
    'state': p.state,
    'zip': p.zip,
  };

  static Place? _place(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    final name = json['name'];
    if (id is! String || name is! String) return null;
    return Place(
      id: id,
      name: name,
      category: PlaceCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => PlaceCategory.activity,
      ),
      details: json['details'] as String? ?? '',
      keywords: json['keywords'] as String? ?? '',
      googlePlaceId: json['googlePlaceId'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      addressLine: json['addressLine'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      zip: json['zip'] as String? ?? '',
    );
  }
}
