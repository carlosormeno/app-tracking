import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/mapbox_config.dart';
import '../models/destination.dart';
import '../models/route_models.dart';
import '../utils/logger.dart';

class MapboxServiceException implements Exception {
  final String message;
  MapboxServiceException(this.message);
  @override
  String toString() => 'MapboxServiceException: $message';
}

enum RoutingMode { walking, driving }

class MapboxService {
  MapboxService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _token {
    final t = MapboxConfig.accessToken;
    if (t.isEmpty) {
      throw MapboxServiceException('Mapbox token no configurado');
    }
    return t;
  }

  Future<List<Destination>> geocode(
    String query, {
    LatLng? proximity,
    String? country,
    String language = 'es',
    int limit = 5,
    String? bbox, // format: minLon,minLat,maxLon,maxLat
    String? types, // e.g., 'poi,address,place,locality'
    bool fuzzyMatch = true,
  }) async {
    final params = <String, String>{
      'autocomplete': 'true',
      'limit': limit.toString(),
      'language': language,
      'access_token': _token,
      'fuzzyMatch': fuzzyMatch ? 'true' : 'false',
      if (proximity != null)
        'proximity': '${proximity.longitude.toStringAsFixed(6)},${proximity.latitude.toStringAsFixed(6)}',
      if (country != null && country.isNotEmpty) 'country': country.toLowerCase(),
      if (bbox != null && bbox.isNotEmpty) 'bbox': bbox,
      if (types != null && types.isNotEmpty) 'types': types,
    };
    final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final uri = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json?$qs',
    );
    final resp = await _client.get(uri);
    if (resp.statusCode != 200) {
      throw MapboxServiceException(
          'Fallo geocoding (${resp.statusCode}): ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final features = (data['features'] as List<dynamic>? ?? []);
    return features.map((f) {
      final m = f as Map<String, dynamic>;
      final coords = (m['center'] as List<dynamic>);
      return Destination(
        id: m['id'] as String? ?? 'unknown',
        name: m['place_name'] as String? ?? 'Sin nombre',
        latitude: (coords[1] as num).toDouble(),
        longitude: (coords[0] as num).toDouble(),
        source: DestinationSource.search,
      );
    }).toList();
  }

  Future<String> reverseGeocode(LatLng point) async {
    final uri = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/'
      '${point.longitude},${point.latitude}.json?limit=1&language=es&access_token=${_token}',
    );
    final resp = await _client.get(uri);
    if (resp.statusCode != 200) {
      throw MapboxServiceException(
          'Fallo reverse geocoding (${resp.statusCode})');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final features = (data['features'] as List<dynamic>? ?? []);
    if (features.isEmpty) return '${point.latitude},${point.longitude}';
    return (features.first as Map<String, dynamic>)['place_name'] as String? ??
        '${point.latitude},${point.longitude}';
  }

  String _profile(RoutingMode mode) =>
      mode == RoutingMode.walking ? 'walking' : 'driving';

  Future<RouteResult> directions({
    required RoutingMode mode,
    required List<LatLng> waypoints,
  }) async {
    if (waypoints.length < 2) {
      throw MapboxServiceException('Se requieren al menos 2 puntos');
    }
    final coords = waypoints
        .map((p) => '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
        .join(';');
    final uri = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/${_profile(mode)}/$coords'
      '?alternatives=false&geometries=geojson&steps=true&overview=full&access_token=${_token}',
    );
    final resp = await _client.get(uri);
    if (resp.statusCode != 200) {
      throw MapboxServiceException(
          'Fallo directions (${resp.statusCode}): ${resp.body}');
    }
    return _parseDirections(resp.body);
  }

  Future<RouteResult> optimize({
    required RoutingMode mode,
    required List<LatLng> waypoints,
    bool sourceFirst = true,
    bool destinationLast = true,
  }) async {
    if (waypoints.length < 2) {
      throw MapboxServiceException('Se requieren al menos 2 puntos');
    }
    final coords = waypoints
        .map((p) => '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
        .join(';');
    final params = <String, String>{
      'geometries': 'geojson',
      'steps': 'true',
      'access_token': _token,
      'roundtrip': 'false',
      if (sourceFirst) 'source': 'first',
      if (destinationLast) 'destination': 'last',
    };
    final qs = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final uri = Uri.parse(
        'https://api.mapbox.com/optimized-trips/v1/mapbox/${_profile(mode)}/$coords?$qs');
    final resp = await _client.get(uri);
    if (resp.statusCode != 200) {
      throw MapboxServiceException(
          'Fallo optimization (${resp.statusCode}): ${resp.body}');
    }
    return _parseOptimization(resp.body);
  }

  RouteResult _parseDirections(String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      throw MapboxServiceException('Sin rutas');
    }
    final r = routes.first as Map<String, dynamic>;
    final geometry = r['geometry'] as Map<String, dynamic>;
    final coords = (geometry['coordinates'] as List<dynamic>)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
    final legs = (r['legs'] as List<dynamic>? ?? []);
    final steps = <RouteStepInfo>[];
    final legInfos = <RouteLegInfo>[];
    for (final leg in legs) {
      final l = leg as Map<String, dynamic>;
      legInfos.add(RouteLegInfo(
        distanceMeters: (l['distance'] as num?)?.toDouble() ?? 0,
        durationSeconds: (l['duration'] as num?)?.toDouble() ?? 0,
      ));
      final s = (l['steps'] as List<dynamic>? ?? []);
      for (final st in s) {
        final m = st as Map<String, dynamic>;
        final maneuver = (m['maneuver'] as Map<String, dynamic>? ?? {});
        final instruction = (maneuver['instruction'] as String?) ?? '';
        steps.add(RouteStepInfo(
          instruction: instruction,
          distanceMeters: (m['distance'] as num?)?.toDouble() ?? 0,
          durationSeconds: (m['duration'] as num?)?.toDouble() ?? 0,
        ));
      }
    }
    return RouteResult(
      coordinates: coords,
      distanceMeters: (r['distance'] as num?)?.toDouble() ?? 0,
      durationSeconds: (r['duration'] as num?)?.toDouble() ?? 0,
      steps: steps,
      legs: legInfos,
    );
  }

  RouteResult _parseOptimization(String body) {
    // optimized-trips returns trips array similar to routes in directions
    final data = jsonDecode(body) as Map<String, dynamic>;
    final trips = data['trips'] as List<dynamic>?;
    if (trips == null || trips.isEmpty) {
      throw MapboxServiceException('Sin viajes optimizados');
    }
    final r = trips.first as Map<String, dynamic>;
    final geometry = r['geometry'] as Map<String, dynamic>;
    final coords = (geometry['coordinates'] as List<dynamic>)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
    final legs = (r['legs'] as List<dynamic>? ?? []);
    final steps = <RouteStepInfo>[];
    final legInfos = <RouteLegInfo>[];
    for (final leg in legs) {
      final l = leg as Map<String, dynamic>;
      legInfos.add(RouteLegInfo(
        distanceMeters: (l['distance'] as num?)?.toDouble() ?? 0,
        durationSeconds: (l['duration'] as num?)?.toDouble() ?? 0,
      ));
      final s = (l['steps'] as List<dynamic>? ?? []);
      for (final st in s) {
        final m = st as Map<String, dynamic>;
        final maneuver = (m['maneuver'] as Map<String, dynamic>? ?? {});
        final instruction = (maneuver['instruction'] as String?) ?? '';
        steps.add(RouteStepInfo(
          instruction: instruction,
          distanceMeters: (m['distance'] as num?)?.toDouble() ?? 0,
          durationSeconds: (m['duration'] as num?)?.toDouble() ?? 0,
        ));
      }
    }
    return RouteResult(
      coordinates: coords,
      distanceMeters: (r['distance'] as num?)?.toDouble() ?? 0,
      durationSeconds: (r['duration'] as num?)?.toDouble() ?? 0,
      steps: steps,
      legs: legInfos,
    );
  }
}
