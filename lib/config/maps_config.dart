/// Google Maps / web API key used by the native SDK and HTTP Directions calls.
///
/// Must match:
/// - `com.google.android.geo.API_KEY` in `AndroidManifest.xml`
/// - `GMSServices.provideAPIKey` in iOS `AppDelegate.swift`
///
/// In [Google Cloud Console](https://console.cloud.google.com/), enable **Directions API**
/// for this key (Maps SDK alone is not enough for turn-by-turn polylines).
///
/// Override at build time: `flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_key`
abstract final class MapsConfig {
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyDuAloVADiL2L-pa1Dg7OIkjPLl-lAE6eA',
  );
}
