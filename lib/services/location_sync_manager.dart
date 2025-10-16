import '../models/location_point.dart';
import '../models/pending_location.dart';
import '../utils/logger.dart';
import 'api_service.dart';
import 'pending_location_store.dart';

class LocationSyncManager {
  LocationSyncManager({
    ApiService? apiService,
    PendingLocationStore? store,
  })  : _apiService = apiService ?? ApiService(),
        _store = store ?? PendingLocationStore();

  final ApiService _apiService;
  final PendingLocationStore _store;

  /// Intenta enviar la ubicación; si falla, la almacena localmente.
  Future<void> sendOrQueue({
    required String firebaseUid,
    required LocationPoint point,
    int? batteryLevel,
    String? activityType,
  }) async {
    logDebug('Intentando enviar ubicación',
        details: 'uid=$firebaseUid lat=${point.latitude} lng=${point.longitude}');
    try {
      await _apiService.sendLocation(
        firebaseUid: firebaseUid,
        point: point,
        batteryLevel: batteryLevel,
        activityType: activityType,
      );
      logDebug('Ubicación enviada correctamente');
      await flushPending();
    } catch (error, stackTrace) {
      logError('Error al enviar ubicación, encolando',
          error: error, stackTrace: stackTrace);
      final pending = PendingLocation(
        firebaseUid: firebaseUid,
        point: point,
        batteryLevel: batteryLevel,
        activityType: activityType,
      );
      await _store.add(pending);
      rethrow;
    }
  }

  /// Reintenta enviar todas las ubicaciones pendientes.
  Future<void> flushPending() async {
    final pendingList = await _store.getAll();
    if (pendingList.isEmpty) return;

    logDebug('Reintentando ${pendingList.length} ubicaciones pendientes');
    final List<PendingLocation> remaining = [];
    for (final pending in pendingList) {
      try {
        await _apiService.sendLocation(
          firebaseUid: pending.firebaseUid,
          point: pending.point,
          batteryLevel: pending.batteryLevel,
          activityType: pending.activityType,
        );
        logDebug('Ubicación pendiente sincronizada',
            details:
                'uid=${pending.firebaseUid} lat=${pending.point.latitude}');
      } catch (error, stackTrace) {
        logError('Ubicación pendiente sigue fallando',
            error: error, stackTrace: stackTrace);
        remaining.add(pending);
      }
    }

    await _store.replaceAll(remaining);

    if (remaining.isNotEmpty) {
      logDebug('Quedaron ${remaining.length} ubicaciones pendientes');
      throw ApiException(
        'No se pudieron sincronizar ${remaining.length} ubicaciones pendientes',
      );
    }
    logDebug('Todas las ubicaciones pendientes fueron sincronizadas');
  }
}
