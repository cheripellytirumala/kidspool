import 'package:dio/dio.dart';

import '../../../core/config/maps_config.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/network/dio_error_mapper.dart';
import '../../../core/services/maps_availability.dart';
import '../../models/place_details_model.dart';
import '../../models/place_suggestion_model.dart';

/// Google Places API (New): autocomplete + place details.
///
/// Throws [NetworkException], [ServerException], [ParsingException], or
/// [DeviceException] when no API key is configured.
abstract interface class PlacesRemoteDataSource {
  Future<List<PlaceSuggestionModel>> autocomplete(
    String input, {
    required String sessionToken,
    double? nearLatitude,
    double? nearLongitude,
  });

  Future<PlaceDetailsModel> details(
    String placeId, {
    required String sessionToken,
  });
}

class PlacesRemoteDataSourceImpl implements PlacesRemoteDataSource {
  /// [dio] is a dedicated client: Google must not receive the app's
  /// Supabase auth headers.
  PlacesRemoteDataSourceImpl(
    this._dio, {
    String apiKey = MapsConfig.apiKey,
    Future<String?> Function() nativeKey = MapsAvailability.nativeApiKey,
  }) : _dartDefineKey = apiKey,
       _nativeKey = nativeKey;

  final Dio _dio;

  /// `--dart-define=GOOGLE_MAPS_API_KEY` if given, otherwise the key from
  /// the native config (Secrets.xcconfig / local.properties).
  final String _dartDefineKey;
  final Future<String?> Function() _nativeKey;
  String? _resolvedKey;

  Future<String> _apiKey() async => _resolvedKey ??= _dartDefineKey.isNotEmpty
      ? _dartDefineKey
      : (await _nativeKey() ?? '');

  static const double _biasRadiusMeters = 50000;

  @override
  Future<List<PlaceSuggestionModel>> autocomplete(
    String input, {
    required String sessionToken,
    double? nearLatitude,
    double? nearLongitude,
  }) async {
    final data = await _send(
      (key) => _dio.post<dynamic>(
        MapsConfig.autocompletePath,
        data: {
          'input': input,
          'sessionToken': sessionToken,
          if (nearLatitude != null && nearLongitude != null)
            'locationBias': {
              'circle': {
                'center': {
                  'latitude': nearLatitude,
                  'longitude': nearLongitude,
                },
                'radius': _biasRadiusMeters,
              },
            },
        },
        options: Options(headers: {MapsConfig.headerApiKey: key}),
      ),
    );
    final suggestions = data['suggestions'];
    if (suggestions == null) return const [];
    if (suggestions is! List) throw const ParsingException();
    return suggestions
        .whereType<Map>()
        .map((s) => PlaceSuggestionModel.fromSuggestion(Map.from(s)))
        .whereType<PlaceSuggestionModel>()
        .toList(growable: false);
  }

  @override
  Future<PlaceDetailsModel> details(
    String placeId, {
    required String sessionToken,
  }) async {
    final data = await _send(
      (key) => _dio.get<dynamic>(
        'places/$placeId',
        queryParameters: {'sessionToken': sessionToken},
        options: Options(
          headers: {
            MapsConfig.headerApiKey: key,
            MapsConfig.headerFieldMask: MapsConfig.detailsFieldMask,
          },
        ),
      ),
    );
    return PlaceDetailsModel(data);
  }

  Future<Map<String, dynamic>> _send(
    Future<Response<dynamic>> Function(String key) request,
  ) async {
    final key = await _apiKey();
    if (key.isEmpty) {
      throw const DeviceException(
        'Address search isn’t set up yet. Drag the map to choose a spot.',
      );
    }
    try {
      final response = await request(key);
      final data = response.data;
      if (data is! Map) throw const ParsingException();
      return Map<String, dynamic>.from(data);
    } on DioException catch (e) {
      throw DioErrorMapper.map(e);
    }
  }
}
