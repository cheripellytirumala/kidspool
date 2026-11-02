# Google Maps address search — setup

"Add a new address" (Ask for a ride → Pick up from / Drop off at) opens a
Google map with a search field. It needs a Google Maps Platform key with
these APIs enabled: **Maps SDK for Android**, **Maps SDK for iOS** and
**Places API (New)**. Restrict the keys per platform in Google Cloud Console.

Keys are never committed. Put them in three places:

1. **Android map** — `android/local.properties` (already git-ignored):
   ```
   MAPS_API_KEY=your-android-key
   ```
2. **iOS map** — copy `ios/Flutter/Secrets.xcconfig.example` to
   `ios/Flutter/Secrets.xcconfig` (git-ignored) and fill in:
   ```
   GOOGLE_MAPS_API_KEY=your-ios-key
   ```
3. **Places search (Dart)** — nothing to do: the app reads the same key from
   the native config above. To use a different key for Places, pass
   `flutter run --dart-define=GOOGLE_MAPS_API_KEY=your-places-key`.

If no native key is set, the app never creates a map view (on iOS that
would crash): the picker shows the map artwork with search and "use my
location" only. `MapsAvailability.isNativeMapConfigured()` in
`lib/common/core/services/maps_availability.dart` is the check every map
screen must use.
