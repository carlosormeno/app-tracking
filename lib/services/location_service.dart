import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/location_point.dart';
import 'foreground_service_manager.dart';
import '../utils/logger.dart';

class LocationServiceException implements Exception {
  final String message;

  LocationServiceException(this.message);

  @override
  String toString() => 'LocationServiceException: $message';
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final StreamController<LocationPoint> _locationController =
      StreamController<LocationPoint>.broadcast();
  static final LocationSettings _defaultSettings = LocationSettings(
    accuracy: LocationAccuracy.medium,
    distanceFilter: 50,
  );
  StreamSubscription<Position>? _positionSub;
  bool _isTracking = false;

  Stream<LocationPoint> get stream => _locationController.stream;
  bool get isTracking => _isTracking;

  Future<bool> _ensurePermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
      }
      return false;
    }
    return true;
  }

  Future<void> start({LocationSettings? settings}) async {
    if (_isTracking) {
      logDebug('Tracking solicitado pero ya estaba activo');
      return;
    }
    logDebug('Iniciando tracking de ubicación');
    final ok = await _ensurePermissions();
    if (!ok) {
      logDebug('Permisos denegados, no se puede iniciar tracking');
      throw LocationServiceException(
        'Permisos de ubicación denegados o servicio desactivado',
      );
    }

    _isTracking = true;
    await _positionSub?.cancel();
    logDebug('Activando servicio foreground');
    await ForegroundServiceManager.instance.startService();
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: settings ?? _defaultSettings,
        ).listen(
          (pos) {
            logDebug('Coordenadas recibidas',
                details: 'lat=${pos.latitude}, lng=${pos.longitude}');
            final point = LocationPoint(
              latitude: pos.latitude,
              longitude: pos.longitude,
              timestamp: pos.timestamp?.toUtc() ?? DateTime.now().toUtc(),
              accuracy: pos.accuracy,
              altitude: pos.altitude,
              speed: pos.speed,
              heading: pos.heading,
            );
            if (!_locationController.isClosed) {
              _locationController.add(point);
            }
          },
          onError: (error, stackTrace) {
            logError('Error en stream de posiciones',
                error: error, stackTrace: stackTrace);
            _isTracking = false;
            if (!_locationController.isClosed) {
              _locationController.addError(error, stackTrace);
            }
          },
          onDone: () {
            logDebug('Stream de geolocalización finalizado');
            _isTracking = false;
          },
        );
  }

  Future<void> stop() async {
    logDebug('Deteniendo tracking de ubicación');
    await _positionSub?.cancel();
    _positionSub = null;
    _isTracking = false;
    await ForegroundServiceManager.instance.stopService();
  }

  Future<LocationPoint?> getCurrentOnce() async {
    final ok = await _ensurePermissions();
    if (!ok) {
      logDebug('Permisos insuficientes para obtener posición actual');
      return null;
    }
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
    logDebug('Posición actual obtenida',
        details: 'lat=${pos.latitude}, lng=${pos.longitude}');
    return LocationPoint(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: pos.timestamp?.toUtc() ?? DateTime.now().toUtc(),
      accuracy: pos.accuracy,
      altitude: pos.altitude,
      speed: pos.speed,
      heading: pos.heading,
    );
  }

  void dispose() {
    _positionSub?.cancel();
    _isTracking = false;
    _locationController.close();
  }
}
