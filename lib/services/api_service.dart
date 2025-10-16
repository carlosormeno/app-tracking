import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../models/location_point.dart';
import '../utils/logger.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  bool _userRegistered = false;
  String? _authToken;

  Uri _buildUri(String path) {
    final base = Constants.apiBaseUrl;
    return Uri.parse('$base$path');
  }

  void updateAuthToken(String? token) {
    _authToken = token;
  }

  Map<String, String> _jsonHeaders() {
    final headers = {'Content-Type': 'application/json'};
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${_authToken!}';
    }
    return headers;
  }

  Future<void> registerUser({
    required String firebaseUid,
    required String email,
  }) async {
    if (_userRegistered) return;
    logDebug('Registrando usuario en API',
        details: 'uid=$firebaseUid email=$email');

    final response = await _client.post(
      _buildUri('/users'),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'firebaseUid': firebaseUid,
        'email': email,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      _userRegistered = true;
      logDebug('Usuario registrado correctamente');
      return;
    }

    throw ApiException(
      'Error registrando usuario (${response.statusCode}): ${response.body}',
    );
  }

  Future<void> sendLocation({
    required String firebaseUid,
    required LocationPoint point,
    int? batteryLevel,
    String? activityType,
  }) async {
    logDebug('Enviando ubicación al backend',
        details:
            'uid=$firebaseUid lat=${point.latitude} lng=${point.longitude}');
    final payload = {
      'firebaseUid': firebaseUid,
      'latitude': point.latitude,
      'longitude': point.longitude,
      'timestamp': point.timestamp.toUtc().toIso8601String(),
      if (point.accuracy != null) 'accuracy': point.accuracy,
      if (point.altitude != null) 'altitude': point.altitude,
      if (point.speed != null) 'speed': point.speed,
      if (point.heading != null) 'heading': point.heading,
      if (batteryLevel != null) 'batteryLevel': batteryLevel,
      if (activityType != null) 'activityType': activityType,
    };

    final response = await _client.post(
      _buildUri('/locations'),
      headers: _jsonHeaders(),
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      logDebug('Ubicación enviada correctamente');
      return;
    }

    throw ApiException(
      'Error enviando ubicación (${response.statusCode}): ${response.body}',
    );
  }

  Future<HistoryResponse> fetchHistory({
    required String firebaseUid,
    required DateTime start,
    required DateTime end,
  }) async {
    logDebug('Solicitando historial',
        details:
            'uid=$firebaseUid start=${start.toIso8601String()} end=${end.toIso8601String()}');
    final uri = _buildUri(
      '/locations/history?firebaseUid=$firebaseUid'
      '&start=${start.toUtc().toIso8601String()}'
      '&end=${end.toUtc().toIso8601String()}',
    );

    final response = await _client.get(uri, headers: _jsonHeaders());
    if (response.statusCode != 200) {
      throw ApiException(
        'Error obteniendo historial (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    logDebug('Historial recibido con ${data['points']?.length ?? 0} puntos');
    return HistoryResponse.fromJson(data);
  }

  Future<double> fetchDailyDistance({
    required String firebaseUid,
    required DateTime date,
  }) async {
    logDebug('Consultando distancia diaria',
        details: 'uid=$firebaseUid date=${date.toIso8601String()}');
    final uri = _buildUri(
      '/locations/distance?firebaseUid=$firebaseUid&date=${date.toIso8601String().split('T').first}',
    );
    final response = await _client.get(uri, headers: _jsonHeaders());
    if (response.statusCode != 200) {
      throw ApiException(
        'Error obteniendo distancia (${response.statusCode}): ${response.body}',
      );
    }
    logDebug('Distancia obtenida: ${response.body}');
    return double.tryParse(response.body) ?? 0.0;
  }

  void dispose() {
    _client.close();
  }
}

class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}

class HistoryResponse {
  HistoryResponse({
    required this.firebaseUid,
    required this.start,
    required this.end,
    required this.points,
    required this.totalDistanceKm,
  });

  final String firebaseUid;
  final DateTime start;
  final DateTime end;
  final List<LocationPoint> points;
  final double totalDistanceKm;

  factory HistoryResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['points'] as List<dynamic>? ?? [])
        .map((item) => _pointFromJson(item as Map<String, dynamic>))
        .toList();
    return HistoryResponse(
      firebaseUid: json['firebaseUid'] as String? ?? '',
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      points: list,
      totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static LocationPoint _pointFromJson(Map<String, dynamic> json) {
    return LocationPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
    );
  }
}
