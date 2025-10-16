import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
  final LocationService _locationService = LocationService();
  final ApiService _apiService = ApiService();
  late final LocationSyncManager _syncManager =
      LocationSyncManager(apiService: _apiService);
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
  StreamSubscription<LocationPoint>? _locationStreamSub;

  @override
  void initState() {
    super.initState();
    logDebug('MapScreen initState');
    _bootstrap();
    _locationStreamSub = _locationService.stream.listen((LocationPoint p) {
      setState(() {
        final point = LatLng(p.latitude, p.longitude);
        _route.add(point);
        _center = point;
      });
      _syncLocation(p);
    });
  }

  Future<void> _bootstrap() async {
    logDebug('MapScreen bootstrap iniciado');
    try {
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
      await _ensureBackendReady();
      final p = await _locationService.getCurrentOnce();
      if (p != null) {
        setState(() {
          _center = LatLng(p.latitude, p.longitude);
        });
      }
      _route.clear();
      _showingHistory = false;
      _lastHistoryPoints = [];
    } catch (e) {
      _showError('Error inicializando: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      logDebug('Bootstrap completado');
    }
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      logDebug('El usuario detuvo el tracking');
      await _locationService.stop();
      setState(() => _isTracking = false);
    } else {
      try {
        logDebug('El usuario inició el tracking');
        final ready = await _ensureBackendReady();
        if (!ready) return;
        await _locationService.start();
        setState(() => _isTracking = true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error iniciando tracking: $e')),
          );
        }
        setState(() => _showingHistory = false);
      }
    }
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
        logError('Fallo al enviar ubicación, quedará en cola',
            error: error, stackTrace: stackTrace);
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
            ..addAll(history.points
                .map((p) => LatLng(p.latitude, p.longitude)));
          if (_route.isNotEmpty) {
            _center = _route.last;
          }
          _lastDistanceKm = history.totalDistanceKm;
          _lastHistoryRange = DateTimeRange(start: history.start, end: history.end);
          _lastHistoryPoints = history.points;
        });
        logDebug('Historial cargado',
            details: 'puntos=${history.points.length} distancia=${history.totalDistanceKm}');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
                    return ListTile(
                      leading: Text('#${index + 1}'),
                      title: Text(
                        'Lat: ${point.latitude.toStringAsFixed(5)}\nLng: ${point.longitude.toStringAsFixed(5)}',
                      ),
                      subtitle: Text(
                        'Hora: ${TimeOfDay.fromDateTime(localTime).format(context)}',
                      ),
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
            tooltip: _showingHistory ? 'Limpiar historial' : 'Refrescar ubicación',
            onPressed: () {
              if (_showingHistory) {
                setState(() {
                  _showingHistory = false;
                  _lastDistanceKm = 0;
                  _lastHistoryRange = null;
                  _route.clear();
                  _lastHistoryPoints = [];
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
              PopupMenuItem(
                value: 'logout',
                child: Text('Cerrar sesión'),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_application_1',
              ),
              if (_route.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(points: _route, color: Colors.blue, strokeWidth: 4),
                  ],
                ),
              if (_route.isNotEmpty)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _route.first,
                      width: 36,
                      height: 36,
                      child: const Icon(Icons.location_on, color: Colors.green, size: 36),
                    ),
                    Marker(
                      point: _route.last,
                      width: 36,
                      height: 36,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 36),
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
                      child: const Icon(Icons.flag, color: Colors.orange, size: 40),
                    ),
                    Marker(
                      point: _route.last,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.flag, color: Colors.purple, size: 40),
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
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleTracking,
        icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
        label: Text(_isTracking ? 'Detener' : 'Iniciar'),
        backgroundColor: _isTracking ? Colors.red : Colors.green,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
