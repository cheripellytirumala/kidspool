import 'package:equatable/equatable.dart';

/// One autocomplete result from the map search field.
class PlaceSuggestion extends Equatable {
  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    this.secondaryText = '',
  });

  final String placeId;

  /// e.g. `24 Maple St`.
  final String primaryText;

  /// e.g. `San Francisco, CA, USA`.
  final String secondaryText;

  @override
  List<Object?> get props => [placeId, primaryText, secondaryText];
}
