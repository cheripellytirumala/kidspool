/// Google Maps Platform configuration.
///
/// The key is never committed. Provide it at build time:
/// `flutter run --dart-define=GOOGLE_MAPS_API_KEY=<key>`
/// The native map SDKs read the same key from `android/local.properties`
/// (`MAPS_API_KEY=`) and `ios/Flutter/Secrets.xcconfig`
/// (`GOOGLE_MAPS_API_KEY=`).
abstract final class MapsConfig {
  static const String apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static bool get isConfigured => apiKey.isNotEmpty;

  /// Places API (New).
  static const String placesBaseUrl = 'https://places.googleapis.com/v1/';
  static const String autocompletePath = 'places:autocomplete';
  static const String headerApiKey = 'X-Goog-Api-Key';
  static const String headerFieldMask = 'X-Goog-FieldMask';
  static const String detailsFieldMask =
      'id,displayName,formattedAddress,location,addressComponents';
}
