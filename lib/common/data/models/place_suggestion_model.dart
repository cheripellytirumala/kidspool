import '../../core/utils/json_parser.dart';
import '../../domain/entities/place_suggestion.dart';

/// `suggestions[].placePrediction` from Places API (New) autocomplete.
class PlaceSuggestionModel {
  const PlaceSuggestionModel({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });

  final String placeId;
  final String mainText;
  final String secondaryText;

  static PlaceSuggestionModel? fromSuggestion(Map<String, dynamic> json) {
    final prediction = json['placePrediction'];
    if (prediction is! Map) return null;
    final p = Map<String, dynamic>.from(prediction);
    final placeId = p.readString('placeId');
    if (placeId == null || placeId.isEmpty) return null;

    final format = _map(p['structuredFormat']);
    final main = _text(format?['mainText']) ?? _text(p['text']) ?? '';
    return PlaceSuggestionModel(
      placeId: placeId,
      mainText: main,
      secondaryText: _text(format?['secondaryText']) ?? '',
    );
  }

  PlaceSuggestion toEntity() => PlaceSuggestion(
    placeId: placeId,
    primaryText: mainText,
    secondaryText: secondaryText,
  );

  static Map<String, dynamic>? _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  static String? _text(Object? v) => _map(v)?.readString('text');
}
