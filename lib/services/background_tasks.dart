import 'dart:async';

import 'package:workmanager/workmanager.dart';

import '../utils/logger.dart';
import 'api_service.dart';
import 'location_sync_manager.dart';

// Task identifiers
const String kPendingFlushTask = 'pendingFlush';

@pragma('vm:entry-point')
void backgroundTaskDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      logDebug('WorkManager task start', details: task);

      if (task == kPendingFlushTask) {
        final token = await ApiService.loadSavedAuthToken();
        final api = ApiService();
        await api.updateAuthToken(token);
        final sync = LocationSyncManager(apiService: api);
        try {
          await sync.flushPending();
        } catch (e) {
          // Keep remaining queued; not a hard failure
          logError('Flush pending failed in background', error: e);
        } finally {
          api.dispose();
        }
      }

      return Future.value(true);
    } catch (e, st) {
      logError('WorkManager task error', error: e, stackTrace: st);
      return Future.value(false);
    }
  });
}

Future<void> registerBackgroundTasks() async {
  try {
    await Workmanager().cancelByUniqueName(kPendingFlushTask);
  } catch (_) {}
  await Workmanager().registerPeriodicTask(
    kPendingFlushTask,
    kPendingFlushTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    initialDelay: const Duration(minutes: 5),
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: const Duration(minutes: 5),
  );
  logDebug('WorkManager periodic flush registered');
}
