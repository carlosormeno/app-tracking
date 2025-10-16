import 'package:shared_preferences/shared_preferences.dart';

import '../models/pending_location.dart';
import '../utils/logger.dart';

class PendingLocationStore {
  static const String _storageKey = 'pending_locations_v1';

  Future<List<PendingLocation>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    logDebug('Recuperando ubicaciones pendientes del storage');
    return PendingLocation.decodeList(raw);
  }

  Future<void> add(PendingLocation item) async {
    final items = await getAll();
    items.add(item);
    logDebug('Agregando ubicación pendiente. Total ahora: ${items.length}');
    await replaceAll(items);
  }

  Future<void> replaceAll(List<PendingLocation> items) async {
    final prefs = await SharedPreferences.getInstance();
    if (items.isEmpty) {
      logDebug('Limpiando storage de ubicaciones pendientes');
      await prefs.remove(_storageKey);
    } else {
      final encoded = PendingLocation.encodeList(items);
      await prefs.setString(_storageKey, encoded);
      logDebug('Persistiendo ${items.length} ubicaciones pendientes');
    }
  }

  Future<void> clear() => replaceAll([]);
}
