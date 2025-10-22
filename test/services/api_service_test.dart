import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/models/location_point.dart';

void main() {
  group('ApiService', () {
    test('registerUser posts payload and handles 201', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, contains('/users'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['firebaseUid'], 'abc');
        return http.Response('{}', 201);
      });
      final api = ApiService(client: client);
      await api.registerUser(firebaseUid: 'abc', email: 'a@b.com');
    });

    test('fetchHistory parses response', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, contains('/locations/history'));
        final payload = {
          'firebaseUid': 'abc',
          'start': DateTime.now().toUtc().toIso8601String(),
          'end': DateTime.now().toUtc().toIso8601String(),
          'totalDistanceKm': 1.23,
          'points': [
            {
              'latitude': -12.05,
              'longitude': -77.05,
              'timestamp': DateTime.now().toUtc().toIso8601String()
            }
          ]
        };
        return http.Response(jsonEncode(payload), 200);
      });
      final api = ApiService(client: client);
      final res = await api.fetchHistory(
        firebaseUid: 'abc',
        start: DateTime.now().toUtc(),
        end: DateTime.now().toUtc(),
      );
      expect(res.totalDistanceKm, 1.23);
      expect(res.points.length, 1);
    });

    test('sendLocation sends correct payload', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, contains('/locations'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['firebaseUid'], 'abc');
        expect(body['latitude'], -12.0);
        return http.Response('{}', 201);
      });
      final api = ApiService(client: client);
      await api.sendLocation(
        firebaseUid: 'abc',
        point: LocationPoint(
          latitude: -12.0,
          longitude: -77.0,
          timestamp: DateTime.now(),
        ),
      );
    });
  });
}

