import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_point.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/identity_service.dart';
import '../services/location_service.dart';
import '../services/location_sync_manager.dart';
import '../utils/logger.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const int _trackingStartHour = 8; // Inicio permitido (08:00 local)
  static const int _trackingEndHour = 17; // Fin permitido (17:00 local)

  final LocationService _locationService = LocationService();
  final ApiService _apiService = ApiService();
  late final LocationSyncManager _syncManager = LocationSyncManager(
    apiService: _apiService,
  );
  final MapController _mapController = MapController();
  final List<LatLng> _route = [];
  bool _isLoading = true;
  bool _isTracking = false;
  bool _backendReady = false;
  String? _firebaseUid;
  String? _email;
  bool _showingHistory = false;
  double _lastDistanceKm = 0.0;
  DateTimeRange? _lastHistoryRange;
  List<LocationPoint> _lastHistoryPoints = [];
  LatLng _center = const LatLng(-12.0464, -77.0428); // Lima por defecto
  bool _mapReady = false;
  bool _outsideScheduleHandled = false;
  String? _shutdownMessage;
  final Map<String, String> _addressCache = {};
  final Map<String, Future<String>> _addressFutureCache = {};
  StreamSubscription<LocationPoint>? _locationStreamSub;

  @override
  void initState() {
    super.initState();
    logDebug('MapScreen initState');
    _bootstrap();
    _locationStreamSub = _locationService.stream.listen((LocationPoint p) {
      final point = LatLng(p.latitude, p.longitude);
      setState(() {
        _route.add(point);
        _center = point;
      });
      _moveCameraTo(point);
      _syncLocation(p);
    });
  }

  Future<void> _bootstrap() async {
    logDebug('MapScreen bootstrap iniciado');
    try {
      if (mounted) {
        setState(() {
          _shutdownMessage = null;
          _outsideScheduleHandled = false;
        });
      } else {
        _shutdownMessage = null;
        _outsideScheduleHandled = false;
      }
      final identity = IdentityService();
      final uid = identity.uid;
      final email = identity.email;
      if (uid == null || email == null) {
        _showError('Sesión no válida. Inicia sesión nuevamente.');
        return;
      }
      final token = await identity.getIdToken();
      if (token == null) {
        logDebug('No se pudo obtener ID token de Firebase');
      }
      _apiService.updateAuthToken(token);
      setState(() {
        _firebaseUid = uid;
        _email = email;
      });
      final ready = await _ensureBackendReady();
      if (!ready) return;
      if (!_isWithinTrackingWindow(DateTime.now())) {
        _handleOutsideTrackingHours();
        return;
      }
      final p = await _locationService.getCurrentOnce();
      if (p != null) {
        setState(() {
          _center = LatLng(p.latitude, p.longitude);
        });
        _moveCameraTo(_center);
      }
      _route.clear();
      _showingHistory = false;
      _lastHistoryPoints = [];
      _addressCache.clear();
      _addressFutureCache.clear();
      await _startTracking(ensureBackend: false);
    } catch (e) {
      _showError('Error inicializando: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      logDebug('Bootstrap completado');
    }
  }

  void _moveCameraTo(LatLng target) {
    if (!_mapReady) return;
    try {
      final zoom = _mapController.camera.zoom;
      _mapController.move(target, zoom);
    } catch (error, stackTrace) {
      logError(
        'No se pudo mover la cámara del mapa',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _startTracking({bool ensureBackend = true}) async {
    if (_isTracking) return;
    if (!_isWithinTrackingWindow(DateTime.now())) {
      _handleOutsideTrackingHours();
      return;
    }
    try {
      if (ensureBackend) {
        final ready = await _ensureBackendReady();
        if (!ready) return;
      }
      logDebug('Tracking iniciado automáticamente');
      await _locationService.start();
      if (mounted) {
        setState(() => _isTracking = true);
      } else {
        _isTracking = true;
      }
    } catch (e) {
      _showError('Error iniciando tracking: $e');
      if (mounted) {
        setState(() => _showingHistory = false);
      } else {
        _showingHistory = false;
      }
    }
  }

  bool _isWithinTrackingWindow(DateTime timestamp) {
    final start = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
      _trackingStartHour,
    );
    final end = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
      _trackingEndHour,
    );
    return !timestamp.isBefore(start) && !timestamp.isAfter(end);
  }

  String _trackingWindowLabel() =>
      '${_trackingStartHour.toString().padLeft(2, '0')}:00 - ${_trackingEndHour.toString().padLeft(2, '0')}:00';

  void _handleOutsideTrackingHours() {
    if (_outsideScheduleHandled) return;
    _outsideScheduleHandled = true;
    final message =
        'Esta aplicación está disponible entre ${_trackingWindowLabel()}. La aplicación se cerrará.';
    unawaited(_locationService.stop());
    if (mounted) {
      setState(() {
        _shutdownMessage = message;
        _isTracking = false;
        _isLoading = false;
      });
    } else {
      _shutdownMessage = message;
      _isTracking = false;
      _isLoading = false;
    }
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        SystemNavigator.pop();
      }
    });
  }

  Future<bool> _ensureBackendReady() async {
    if (_backendReady) return true;
    final uid = _firebaseUid;
    final email = _email;
    if (uid == null || email == null) {
      _showError('No hay identidad para registrar el usuario');
      return false;
    }
    try {
      final token = await IdentityService().getIdToken();
      _apiService.updateAuthToken(token);
      if (token == null) {
        logDebug('ID token nulo durante el registro');
      }
      await _apiService.registerUser(firebaseUid: uid, email: email);
      if (mounted) {
        setState(() => _backendReady = true);
      } else {
        _backendReady = true;
      }
      logDebug('Usuario registrado en backend');
      await _tryFlushPending();
      return true;
    } catch (e) {
      _showError('No se pudo registrar el usuario: $e');
      return false;
    }
  }

  void _syncLocation(LocationPoint point) {
    final uid = _firebaseUid;
    if (!_backendReady || uid == null) return;
    unawaited(() async {
      try {
        await _syncManager.sendOrQueue(firebaseUid: uid, point: point);
      } catch (error, stackTrace) {
        logError(
          'Fallo al enviar ubicación, quedará en cola',
          error: error,
          stackTrace: stackTrace,
        );
        _showError('Ubicación almacenada localmente: $error');
      }
    }());
  }

  Future<void> _loadTodayHistory() async {
    final uid = _firebaseUid;
    if (uid == null) {
      _showError('No hay usuario registrado');
      return;
    }
    logDebug('Solicitando historial del día actual');
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    try {
      final history = await _apiService.fetchHistory(
        firebaseUid: uid,
        start: start,
        end: end,
      );
      if (mounted) {
        setState(() {
          _showingHistory = true;
          _route
            ..clear()
            ..addAll(
              history.points.map((p) => LatLng(p.latitude, p.longitude)),
            );
          if (_route.isNotEmpty) {
            _center = _route.last;
          }
          _lastDistanceKm = history.totalDistanceKm;
          _lastHistoryRange = DateTimeRange(
            start: history.start,
            end: history.end,
          );
          _lastHistoryPoints = history.points;
          _addressCache.clear();
          _addressFutureCache.clear();
        });
        if (_route.isNotEmpty) {
          _moveCameraTo(_route.last);
        }
        logDebug(
          'Historial cargado',
          details:
              'puntos=${history.points.length} distancia=${history.totalDistanceKm}',
        );
      }
    } catch (e) {
      _showError('No se pudo cargar historial: $e');
    }
  }

  Future<void> _tryFlushPending() async {
    try {
      await _syncManager.flushPending();
      logDebug('Flush de ubicaciones pendientes finalizado');
    } catch (e) {
      _showError('Quedan ubicaciones pendientes: $e');
    }
  }

  void _showError(String message) {
    logError('Mostrando error al usuario', error: message);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showHistoryDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        if (_lastHistoryPoints.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No hay puntos disponibles'),
          );
        }
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                'Detalle de historial',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 320,
                child: ListView.separated(
                  itemCount: _lastHistoryPoints.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final point = _lastHistoryPoints[index];
                    final localTime = point.timestamp.toLocal();
                    final timeLabel = TimeOfDay.fromDateTime(
                      localTime,
                    ).format(context);
                    final coordsLabel = _formatCoordinates(point);
                    return FutureBuilder<String>(
                      future: _resolveAddress(point),
                      builder: (context, snapshot) {
                        final isWaiting =
                            snapshot.connectionState == ConnectionState.waiting;
                        final address = snapshot.data;
                        final displayAddress =
                            (address != null && address.trim().isNotEmpty)
                            ? address
                            : (isWaiting
                                  ? 'Buscando dirección...'
                                  : coordsLabel);
                        final subtitleLines = <String>['Hora: $timeLabel'];
                        if (displayAddress != coordsLabel) {
                          subtitleLines.add(coordsLabel);
                        }
                        return ListTile(
                          leading: Text('#${index + 1}'),
                          title: Text(displayAddress),
                          subtitle: Text(subtitleLines.join('\n')),
                          trailing: isWaiting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _mapReady = false;
    _locationStreamSub?.cancel();
    if (_locationService.isTracking) {
      unawaited(_locationService.stop());
    }
    _apiService.dispose();
    super.dispose();
  }

  String _formatRange(DateTimeRange range) {
    final startLocal = range.start.toLocal();
    return '${startLocal.day}/${startLocal.month}/${startLocal.year}';
  }

  String _formatCoordinates(LocationPoint point) =>
      'Lat: ${point.latitude.toStringAsFixed(5)}, Lng: ${point.longitude.toStringAsFixed(5)}';

  String _coordinateKey(LocationPoint point) =>
      '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}';

  Future<String> _resolveAddress(LocationPoint point) {
    final key = _coordinateKey(point);
    final cached = _addressCache[key];
    if (cached != null) {
      return Future.value(cached);
    }
    final pending = _addressFutureCache[key];
    if (pending != null) {
      return pending;
    }
    final future = _fetchAddress(point)
        .then((value) {
          _addressCache[key] = value;
          _addressFutureCache.remove(key);
          return value;
        })
        .catchError((error, stackTrace) {
          logError(
            'No se pudo obtener la dirección',
            error: error,
            stackTrace: stackTrace,
          );
          final fallback = _formatCoordinates(point);
          _addressCache[key] = fallback;
          _addressFutureCache.remove(key);
          return fallback;
        });
    _addressFutureCache[key] = future;
    return future;
  }

  Future<String> _fetchAddress(LocationPoint point) async {
    final placemarks = await placemarkFromCoordinates(
      point.latitude,
      point.longitude,
      localeIdentifier: 'es',
    );
    if (placemarks.isEmpty) {
      return _formatCoordinates(point);
    }
    final placemark = placemarks.first;
    final streetLine = _joinNonEmpty([
      placemark.street,
      placemark.subThoroughfare,
    ]);
    final localityLine = _joinNonEmpty([
      placemark.subLocality,
      placemark.locality,
    ]);
    final regionLine = _joinNonEmpty([
      placemark.administrativeArea,
      placemark.postalCode,
    ]);

    final segments = <String>[
      if (streetLine != null) streetLine,
      if (localityLine != null) localityLine,
      if (regionLine != null) regionLine,
      if (placemark.country != null && placemark.country!.trim().isNotEmpty)
        placemark.country!.trim(),
    ];
    final filtered = segments.where((element) => element.trim().isNotEmpty);
    final address = filtered.join(', ');
    return address.isNotEmpty ? address : _formatCoordinates(point);
  }

  String? _joinNonEmpty(List<String?> parts, {String separator = ' '}) {
    final filtered = parts
        .where((part) => part != null && part.trim().isNotEmpty)
        .map((part) => part!.trim())
        .toList();
    if (filtered.isEmpty) return null;
    return filtered.join(separator);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking de ubicación (MVP)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Ver historial (día actual)',
            onPressed: _loadTodayHistory,
          ),
          IconButton(
            icon: Icon(_showingHistory ? Icons.clear : Icons.my_location),
            tooltip: _showingHistory
                ? 'Limpiar historial'
                : 'Refrescar ubicación',
            onPressed: () {
              if (_showingHistory) {
                setState(() {
                  _showingHistory = false;
                  _lastDistanceKm = 0;
                  _lastHistoryRange = null;
                  _route.clear();
                  _lastHistoryPoints = [];
                  _addressCache.clear();
                  _addressFutureCache.clear();
                });
              }
              _bootstrap();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                if (_isTracking) {
                  await _locationService.stop();
                  if (mounted) {
                    setState(() => _isTracking = false);
                  }
                }
                _apiService.updateAuthToken(null);
                await AuthService().signOut();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 14,
              onMapReady: () {
                _mapReady = true;
                _moveCameraTo(_center);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_application_1',
              ),
              if (_route.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _route,
                      color: Colors.blue,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              if (_route.isNotEmpty)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _route.first,
                      width: 36,
                      height: 36,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.green,
                        size: 36,
                      ),
                    ),
                    Marker(
                      point: _route.last,
                      width: 36,
                      height: 36,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              if (_route.isEmpty)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _center,
                      width: 32,
                      height: 32,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              if (_showingHistory && _route.isNotEmpty)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _route.first,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.flag,
                        color: Colors.orange,
                        size: 40,
                      ),
                    ),
                    Marker(
                      point: _route.last,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.flag,
                        color: Colors.purple,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_showingHistory && _route.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Historial (${_lastHistoryRange != null ? _formatRange(_lastHistoryRange!) : 'N/A'})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Distancia total: ${_lastDistanceKm.toStringAsFixed(2)} km',
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Puntos: ${_route.length}'),
                          TextButton.icon(
                            onPressed: () {
                              _showHistoryDetails(context);
                            },
                            icon: const Icon(Icons.list_alt),
                            label: const Text('Ver detalle'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (_shutdownMessage != null)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _shutdownMessage!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: null,
        icon: Icon(_isTracking ? Icons.location_on : Icons.hourglass_top),
        label: Text(_isTracking ? 'Sistema activo' : 'Activando sistema...'),
        backgroundColor: _isTracking ? Colors.green : Colors.blueGrey,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
