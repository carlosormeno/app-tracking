// Centralized Mapbox configuration.
// Set tokens via --dart-define at run/build time to avoid committing secrets.

class MapboxConfig {
  // Primary token for Mapbox services (tiles, directions, geocoding, optimization).
  // Usage: flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk.XXXX
  static const String accessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );

  // Optional: style ID for tiles (e.g., 'mapbox/streets-v12').
  static const String styleId = String.fromEnvironment(
    'MAPBOX_STYLE_ID',
    defaultValue: 'mapbox/streets-v12',
  );

  static bool get isConfigured => accessToken.isNotEmpty;
}

