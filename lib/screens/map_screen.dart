import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import '../config/mapbox_config.dart';
import '../models/location_point.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/identity_service.dart';
import '../services/location_service.dart';
import '../services/location_sync_manager.dart';
import '../utils/logger.dart';
import '../models/destination.dart';
import '../models/route_models.dart';
import '../services/mapbox_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const int _trackingStartHour = 8; // Inicio permitido (08:00 local)
  static const int _trackingEndHour = 18; // Fin permitido (17:00 local)
  // Toggle para forzar corte automático al llegar a la hora de fin.
  // Mantener en false para desactivado (comportamiento actual).
  // Poner en true para que, si el tracking está activo, se detenga y cierre la app
  // exactamente a las _trackingEndHour del día local.
  static const bool _enforceEndHour = false; // cambiar a true para activar

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
  String? _connectionMessage;
  final Map<String, String> _addressCache = {};
  final Map<String, Future<String>> _addressFutureCache = {};
  StreamSubscription<LocationPoint>? _locationStreamSub;
  // Timer opcional que, si está habilitado, corta el tracking al llegar al fin de horario
  // y cierra la aplicación. Desactivado por defecto via _enforceEndHour.
  Timer? _scheduleEnforcer;
  // Planificador de rutas (Mapbox)
  final MapboxService _mapbox = MapboxService();
  final List<Destination> _plannerStops = [];
  RoutingMode _routingMode = RoutingMode.walking;
  bool _optimizeStops = true;
  RouteResult? _activeRoute;
  bool _plannerActive = false;
  bool _fixOriginFirst = true;
  bool _fixDestinationLast = true;
  bool _useCurrentAsOrigin = true;
  bool _startNotified = false;
  bool _selectingOnMap = false;

  String? _nearbyBboxString(LatLng center, double deltaDegrees) {
    final minLat = center.latitude - deltaDegrees;
    final maxLat = center.latitude + deltaDegrees;
    final minLon = center.longitude - deltaDegrees;
    final maxLon = center.longitude + deltaDegrees;
    return '${minLon.toStringAsFixed(6)},${minLat.toStringAsFixed(6)},${maxLon.toStringAsFixed(6)},${maxLat.toStringAsFixed(6)}';
  }

  // Tries to use the current map viewport as bbox. Falls back to a delta box.
  String? _currentViewportBboxString() {
    try {
      final bounds = _mapController.camera.visibleBounds;
      final south = bounds.south;
      final west = bounds.west;
      final north = bounds.north;
      final east = bounds.east;
      return '${west.toStringAsFixed(6)},${south.toStringAsFixed(6)},${east.toStringAsFixed(6)},${north.toStringAsFixed(6)}';
    } catch (_) {
      return null;
    }
  }

  double _deltaForZoom(double zoom) {
    if (zoom >= 16) return 0.02; // ~2 km
    if (zoom >= 15) return 0.03;
    if (zoom >= 14) return 0.05;
    if (zoom >= 13) return 0.08;
    if (zoom >= 12) return 0.12;
    if (zoom >= 11) return 0.20;
    if (zoom >= 10) return 0.35;
    return 0.6; // very broad
  }

  String? _dynamicLocalBboxString() {
    final byViewport = _currentViewportBboxString();
    if (byViewport != null) return byViewport;
    final z = _mapController.camera.zoom;
    final delta = _deltaForZoom(z);
    return _nearbyBboxString(_center, delta);
  }

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
          _connectionMessage = null;
          _outsideScheduleHandled = false;
        });
      } else {
        _shutdownMessage = null;
        _connectionMessage = null;
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
      await _apiService.updateAuthToken(token);
      setState(() {
        _firebaseUid = uid;
        _email = email;
      });
      final ready = await _ensureBackendReady();
      if (!ready) {
        if (mounted) {
          setState(() {
            _connectionMessage =
                'No se pudo conectar con el servidor. Reintenta en unos segundos.';
          });
        } else {
          _connectionMessage =
              'No se pudo conectar con el servidor. Reintenta en unos segundos.';
        }
        // Continuar con el tracking en modo offline: se encolarán puntos
      }
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

  void _zoomBy(double delta) {
    if (!_mapReady) return;
    try {
      final camera = _mapController.camera;
      final newZoom = (camera.zoom + delta).clamp(1.0, 19.0);
      _mapController.move(camera.center, newZoom);
    } catch (error, stackTrace) {
      logError(
        'No se pudo ajustar el zoom',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _zoomIn() => _zoomBy(1.0);
  void _zoomOut() => _zoomBy(-1.0);

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
        // Programa el corte automático al llegar a la hora de fin (si está activado)
        if (_enforceEndHour) _rescheduleScheduleEnforcer();
        if (!_startNotified) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Sistema activo')));
          _startNotified = true;
        }
      } else {
        _isTracking = true;
        if (_enforceEndHour) _rescheduleScheduleEnforcer();
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

  // Programa/cancela un timer para cortar al llegar a _trackingEndHour.
  // Solo se programa si el tracking está activo y _enforceEndHour = true.
  void _rescheduleScheduleEnforcer() {
    _scheduleEnforcer?.cancel();
    if (!_isTracking || !_enforceEndHour) return;
    final now = DateTime.now();
    // Si ya estamos fuera de la ventana, cortar de inmediato
    if (!_isWithinTrackingWindow(now)) {
      _handleOutsideTrackingHours();
      return;
    }
    final end = DateTime(now.year, now.month, now.day, _trackingEndHour);
    final duration = end.difference(now);
    if (duration.isNegative || duration.inSeconds == 0) {
      _handleOutsideTrackingHours();
    } else {
      _scheduleEnforcer = Timer(duration, _handleOutsideTrackingHours);
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
      await _apiService.updateAuthToken(token);
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
      logError('Fallo de backend al registrar usuario', error: e);
      return false;
    }
  }

  void _syncLocation(LocationPoint point) {
    final uid = _firebaseUid;
    // Permitir encolar incluso si el backend no está listo (offline/registro pendiente)
    if (uid == null) return;
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
    logDebug('Solicitando historial del dí­a actual');
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

  void _handleMapLongPress(TapPosition tapPosition, LatLng point) async {
    if (!(_plannerActive || _selectingOnMap)) return;
    String name;
    try {
      name = await _mapbox.reverseGeocode(point);
    } catch (_) {
      name =
          '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    }
    if (_plannerStops.length >= 5) {
      _showError('Máximo 5 destinos');
      return;
    }
    setState(() {
      _plannerStops.add(
        Destination(
          id: 'map_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          latitude: point.latitude,
          longitude: point.longitude,
          source: DestinationSource.map,
        ),
      );
      if (_selectingOnMap) {
        _selectingOnMap = false;
        Future.microtask(_openRoutePlanner);
      }
    });
  }

  Future<void> _loadHistoryForDate(DateTime date) async {
    final uid = _firebaseUid;
    if (uid == null) {
      _showError('No hay usuario registrado');
      return;
    }
    logDebug('Solicitando historial por fecha');
    final start = DateTime.utc(date.year, date.month, date.day);
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
          'Historial cargado por fecha',
          details:
              'puntos=${history.points.length} distancia=${history.totalDistanceKm}',
        );
      }
    } catch (e) {
      _showError('No se pudo cargar historial: $e');
    }
  }

  Future<void> _selectAndLoadHistory() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
      helpText: 'Selecciona una fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked == null) return;
    await _loadHistoryForDate(picked);
  }

  Future<void> _selectAndLoadHistoryRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 1)),
        end: DateTime.now(),
      ),
      helpText: 'Selecciona un rango de fechas',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked == null) return;
    await _loadHistoryForRange(picked);
  }

  Future<void> _loadHistoryForRange(DateTimeRange range) async {
    final uid = _firebaseUid;
    if (uid == null) {
      _showError('No hay usuario registrado');
      return;
    }
    logDebug('Solicitando historial por rango');
    final startUtc = DateTime.utc(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final endUtc = DateTime.utc(
      range.end.year,
      range.end.month,
      range.end.day,
    ).add(const Duration(days: 1));

    try {
      final history = await _apiService.fetchHistory(
        firebaseUid: uid,
        start: startUtc,
        end: endUtc,
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
          'Historial cargado por rango',
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
                          subtitle: Text(subtitleLines.join('')),
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
    _scheduleEnforcer?.cancel();
    if (_locationService.isTracking) {
      unawaited(_locationService.stop());
    }
    _apiService.dispose();
    super.dispose();
  }

  String _formatRange(DateTimeRange range) {
    final startLocal = range.start.toLocal();
    final endLocal = range.end.toLocal();
    String fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
    if (startLocal.year == endLocal.year &&
        startLocal.month == endLocal.month &&
        startLocal.day == endLocal.day) {
      return fmt(startLocal);
    }
    return '${fmt(startLocal)} - ${fmt(endLocal)}';
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

  void _showRouteSteps() {
    final route = _activeRoute;
    if (route == null) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        if (route.steps.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No hay instrucciones disponibles'),
          );
        }
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: route.steps.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final s = route.steps[index];
              return ListTile(
                leading: Text('#${index + 1}'),
                title: Text(
                  s.instruction.isEmpty ? 'Paso ${index + 1}' : s.instruction,
                ),
                subtitle: Text(
                  'Distancia: ${(s.distanceMeters / 1000).toStringAsFixed(2)} km • Tiempo: ${(s.durationSeconds / 60).toStringAsFixed(0)} min',
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _shareActiveRoute() async {
    final route = _activeRoute;
    if (route == null) return;
    final modeLabel = _routingMode == RoutingMode.walking
        ? 'Caminar'
        : 'Conducir';
    final buffer = StringBuffer()
      ..writeln('Ruta ($modeLabel)')
      ..writeln(
        'Distancia: ${(route.distanceMeters / 1000).toStringAsFixed(2)} km',
      )
      ..writeln(
        'Tiempo: ${(route.durationSeconds / 60).toStringAsFixed(0)} min',
      )
      ..writeln('')
      ..writeln('Instrucciones:');
    for (var i = 0; i < route.steps.length; i++) {
      final s = route.steps[i];
      buffer.writeln(
        '${i + 1}. ${s.instruction.isEmpty ? 'Paso ${i + 1}' : s.instruction}',
      );
    }
    await Share.share(buffer.toString(), subject: 'Ruta Thaqhiri');
  }

  Future<void> _startExternalNavigation() async {
    if (_plannerStops.isEmpty && _activeRoute == null) {
      _showError('No hay ruta para iniciar');
      return;
    }
    final mode = _routingMode == RoutingMode.walking ? 'walking' : 'driving';
    String originParam;
    if (_useCurrentAsOrigin) {
      originParam = 'origin=Current+Location';
    } else if (_plannerStops.isNotEmpty) {
      final o = _plannerStops.first;
      originParam = 'origin=${o.latitude},${o.longitude}';
    } else {
      originParam = 'origin=Current+Location';
    }
    String destinationParam;
    if (_plannerStops.isNotEmpty) {
      final d = _plannerStops.last;
      destinationParam = 'destination=${d.latitude},${d.longitude}';
    } else {
      // fallback to map center if no planner stops (unlikely)
      destinationParam = 'destination=${_center.latitude},${_center.longitude}';
    }
    // Include intermediate waypoints if any (Google Maps supports limited count)
    final mid = _plannerStops.length > 2
        ? _plannerStops
              .sublist(1, _plannerStops.length - 1)
              .map((s) => '${s.latitude},${s.longitude}')
              .join('|')
        : '';
    final waypointsParam = mid.isNotEmpty ? '&waypoints=$mid' : '';
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&$originParam&$destinationParam$waypointsParam&travelmode=$mode',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showError('No se pudo abrir Google Maps');
    }
  }

  void _showRouteLegs() {
    final route = _activeRoute;
    if (route == null) return;
    final legs = route.legs;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        if (legs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No hay tramos disponibles'),
          );
        }
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: legs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final l = legs[index];
              return ListTile(
                leading: Text('#${index + 1}'),
                title: const Text('Tramo'),
                subtitle: Text(
                  'Distancia: ${(l.distanceMeters / 1000).toStringAsFixed(2)} km • Tiempo: ${(l.durationSeconds / 60).toStringAsFixed(0)} min',
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/onp_logo.png',
              height: 28,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
            const Text('Thaqhiri'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Refrescar ubicación',
            onPressed: () {
              _bootstrap();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'route_planner') {
                await _openRoutePlanner();
                return;
              }
              if (value == 'history') {
                await _selectAndLoadHistory();
                return;
              }
              if (value == 'history_range') {
                await _selectAndLoadHistoryRange();
                return;
              }
              if (value == 'logout') {
                if (_isTracking) {
                  await _locationService.stop();
                  if (mounted) {
                    setState(() => _isTracking = false);
                  }
                }
                await _apiService.updateAuthToken(null);
                await AuthService().signOut();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'route_planner',
                child: Text('Planificar ruta'),
              ),
              PopupMenuItem(
                value: 'history',
                child: Text('Ver historial por fecha'),
              ),
              PopupMenuItem(
                value: 'history_range',
                child: Text('Ver historial por rango'),
              ),
              PopupMenuDivider(),
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
              onLongPress: _handleMapLongPress,
              onTap: _handleMapLongPress,
            ),
            children: [
              TileLayer(
                urlTemplate: MapboxConfig.isConfigured
                    ? 'https://api.mapbox.com/styles/v1/{styleId}/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                additionalOptions: MapboxConfig.isConfigured
                    ? {
                        'accessToken': MapboxConfig.accessToken,
                        'styleId': MapboxConfig.styleId,
                      }
                    : const <String, String>{},
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
              if (_activeRoute != null && _activeRoute!.coordinates.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _activeRoute!.coordinates,
                      color: Colors.deepPurple,
                      strokeWidth: 5,
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
          if (_activeRoute != null)
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
                        'Ruta calculada (${_routingMode == RoutingMode.walking ? 'Caminar' : 'Conducir'})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Distancia: ${(_activeRoute!.distanceMeters / 1000).toStringAsFixed(2)} km • Tiempo: ${(_activeRoute!.durationSeconds / 60).toStringAsFixed(0)} min',
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: _showRouteSteps,
                            icon: const Icon(Icons.list_alt),
                            label: const Text('Ver pasos'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _showRouteLegs,
                            icon: const Icon(Icons.route),
                            label: const Text('Ver tramos'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _startExternalNavigation,
                            icon: const Icon(Icons.navigation),
                            label: const Text('Iniciar'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _shareActiveRoute,
                            icon: const Icon(Icons.share),
                            label: const Text('Compartir'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ),
          if (_isLoading) const Center(child: _AnimatedLoading()),
          // Controles de zoom (+/-)
          Positioned(
            bottom: 20,
            left: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: null,
                  onPressed: _mapReady ? _zoomIn : null,
                  tooltip: 'Acercar',
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: null,
                  onPressed: _mapReady ? _zoomOut : null,
                  tooltip: 'Alejar',
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
          if (_activeRoute != null)
            Positioned(
              bottom: 20,
              right: 16,
              child: ElevatedButton.icon(
                onPressed: _startExternalNavigation,
                icon: const Icon(Icons.navigation),
                label: const Text('Iniciar'),
              ),
            ),
          if (_selectingOnMap)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.black87,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Toca o mantén presionado el mapa para añadir un destino',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _selectingOnMap = false);
                        },
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
          if (_connectionMessage != null)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.cloud_off,
                            color: Colors.orange,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _connectionMessage!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _connectionMessage = null;
                              });
                              _bootstrap();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
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
    );
  }

  Future<void> _openRoutePlanner() async {
    setState(() => _plannerActive = true);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final queryController = TextEditingController();
        bool localOptimize = _optimizeStops;
        bool localFixOrigin = _fixOriginFirst;
        bool localFixDestination = _fixDestinationLast;
        bool localUseCurrent = _useCurrentAsOrigin;
        List<Destination> suggestions = [];
        RoutingMode localMode = _routingMode;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> addBySearch() async {
              final q = queryController.text.trim();
              if (q.isEmpty) return;
              try {
                // Try with POIs and local constraints first, then broaden
                final bbox = _dynamicLocalBboxString();
                var results = await _mapbox.geocode(
                  q,
                  proximity: _center,
                  country: 'PE',
                  limit: 8,
                  bbox: bbox,
                  types: 'poi,address,place,locality,neighborhood',
                );
                if (results.isEmpty) {
                  results = await _mapbox.geocode(
                    q,
                    proximity: _center,
                    country: 'PE',
                    limit: 8,
                    types: 'poi,address,place,locality,neighborhood',
                  );
                }
                if (results.isEmpty) {
                  results = await _mapbox.geocode(
                    q,
                    proximity: _center,
                    limit: 8,
                    types: 'poi,address,place,locality,neighborhood',
                  );
                }
                if (results.isEmpty) {
                  _showError('Sin resultados para "$q"');
                  return;
                }
                if (_plannerStops.length >= 5) {
                  _showError('Máximo 5 destinos');
                  return;
                }
                setState(() => _plannerStops.add(results.first));
                setSheetState(() {});
                queryController.clear();
                suggestions = [];
              } catch (e) {
                _showError('Error buscando: $e');
              }
            }

            void searchSuggestions(String q) async {
              final query = q.trim();
              if (query.length < 3) {
                setSheetState(() => suggestions = []);
                return;
              }
              try {
                // First try with local restrictions and POIs
                final bbox = _dynamicLocalBboxString();
                var results = await _mapbox.geocode(
                  query,
                  proximity: _center,
                  country: 'PE',
                  limit: 8,
                  bbox: bbox,
                  types: 'poi,address,place,locality,neighborhood',
                );
                // Fallbacks to broaden search
                if (results.isEmpty) {
                  results = await _mapbox.geocode(
                    query,
                    proximity: _center,
                    country: 'PE',
                    limit: 8,
                    types: 'poi,address,place,locality,neighborhood',
                  );
                }
                if (results.isEmpty) {
                  results = await _mapbox.geocode(
                    query,
                    proximity: _center,
                    limit: 8,
                    types: 'poi,address,place,locality,neighborhood',
                  );
                }
                setSheetState(() => suggestions = results);
              } catch (_) {
                setSheetState(() => suggestions = []);
              }
            }

            Future<void> calculate() async {
              if (localUseCurrent) {
                if (_plannerStops.isEmpty) {
                  _showError('Agrega al menos un destino');
                  return;
                }
              } else {
                if (_plannerStops.length < 2) {
                  _showError('Agrega al menos origen y destino');
                  return;
                }
              }
              try {
                final points = <LatLng>[
                  if (localUseCurrent) _center,
                  ..._plannerStops
                      .map((d) => LatLng(d.latitude, d.longitude))
                      .toList(),
                ];
                final result = (localOptimize && points.length > 2)
                    ? await _mapbox.optimize(
                        mode: localMode,
                        waypoints: points,
                        sourceFirst: localUseCurrent ? true : localFixOrigin,
                        destinationLast: localFixDestination,
                      )
                    : await _mapbox.directions(
                        mode: localMode,
                        waypoints: points,
                      );
                if (!mounted) return;
                setState(() => _activeRoute = result);
                Navigator.of(context).pop();
              } catch (e) {
                _showError('No se pudo calcular ruta: $e');
              }
            }

            void removeAt(int index) {
              setState(() => _plannerStops.removeAt(index));
              setSheetState(() {});
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Planificador de ruta',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Caminar'),
                          selected: localMode == RoutingMode.walking,
                          onSelected: (_) {
                            setSheetState(
                              () => localMode = RoutingMode.walking,
                            );
                            setState(() => _routingMode = RoutingMode.walking);
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Conducir (aprox. bus)'),
                          selected: localMode == RoutingMode.driving,
                          onSelected: (_) {
                            setSheetState(
                              () => localMode = RoutingMode.driving,
                            );
                            setState(() => _routingMode = RoutingMode.driving);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: queryController,
                            decoration: const InputDecoration(
                              labelText: 'Buscar dirección o lugar',
                            ),
                            onChanged: searchSuggestions,
                            onSubmitted: (_) => addBySearch(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: addBySearch,
                          child: const Text('Añadir'),
                        ),
                      ],
                    ),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: Material(
                          elevation: 2,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: suggestions.length,
                            itemBuilder: (context, index) {
                              final s = suggestions[index];
                              return ListTile(
                                dense: true,
                                title: Text(s.name),
                                subtitle: Text(
                                  'Lat: ${s.latitude.toStringAsFixed(5)}, Lng: ${s.longitude.toStringAsFixed(5)}',
                                ),
                                trailing: TextButton(
                                  onPressed: () {
                                    if (_plannerStops.length >= 5) {
                                      _showError('Máximo 5 destinos');
                                      return;
                                    }
                                    setState(() => _plannerStops.add(s));
                                    setSheetState(() {
                                      suggestions = [];
                                    });
                                    queryController.clear();
                                  },
                                  child: const Text('Añadir'),
                                ),
                                onTap: () {
                                  if (_plannerStops.length >= 5) {
                                    _showError('Máximo 5 destinos');
                                    return;
                                  }
                                  setState(() => _plannerStops.add(s));
                                  setSheetState(() {
                                    suggestions = [];
                                  });
                                  queryController.clear();
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          setState(() => _selectingOnMap = true);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Selecciona un punto en el mapa (tap o long-press)',
                              ),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_location_alt),
                        label: const Text('Seleccionar en el mapa'),
                      ),
                    ),

                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: localUseCurrent,
                            onChanged: (v) {
                              setSheetState(() => localUseCurrent = v);
                              setState(() => _useCurrentAsOrigin = v);
                            },
                          ),
                          const Text('Usar mi ubicación como origen'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: localOptimize,
                            onChanged: (v) {
                              setSheetState(() => localOptimize = v);
                              setState(() => _optimizeStops = v);
                            },
                          ),
                          const Text('Optimizar orden'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 16,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: localFixOrigin,
                                onChanged: (v) {
                                  setSheetState(() => localFixOrigin = v);
                                  setState(() => _fixOriginFirst = v);
                                },
                              ),
                              const Text('Fijar origen (1Â°)'),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: localFixDestination,
                                onChanged: (v) {
                                  setSheetState(() => localFixDestination = v);
                                  setState(() => _fixDestinationLast = v);
                                },
                              ),
                              const Text('Fijar destino (último)'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _plannerStops.length,
                        itemBuilder: (context, index) {
                          final d = _plannerStops[index];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(child: Text('${index + 1}')),
                            title: Text(d.name),
                            subtitle: Text(
                              'Lat: ${d.latitude.toStringAsFixed(5)}, Lng: ${d.longitude.toStringAsFixed(5)}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => removeAt(index),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _plannerStops.clear();
                              _activeRoute = null;
                            });
                            setSheetState(() {});
                          },
                          child: const Text('Limpiar selección'),
                        ),
                        ElevatedButton.icon(
                          onPressed: calculate,
                          icon: const Icon(Icons.alt_route),
                          label: const Text('Calcular ruta'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (mounted) {
      setState(() => _plannerActive = false);
    } else {
      _plannerActive = false;
    }
  }
}

class _AnimatedLoading extends StatelessWidget {
  const _AnimatedLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated GIF for loading; safe fallback if asset missing
        Image.asset(
          'assets/images/loading_search.gif',
          width: 160,
          height: 160,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Buscando ubicaciones...',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
