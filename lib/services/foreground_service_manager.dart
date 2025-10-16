import 'dart:isolate';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../utils/logger.dart';

class ForegroundServiceManager {
  ForegroundServiceManager._internal();

  static final ForegroundServiceManager instance =
      ForegroundServiceManager._internal();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    logDebug('Inicializando ForegroundServiceManager');
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'location_tracking_channel',
        channelName: 'Location Tracking',
        channelDescription: 'Mantiene el tracking activo en segundo plano',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
        buttons: const [NotificationButton(id: 'stop', text: 'Detener')],
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 60000,
        isOnceEvent: false,
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _initialized = true;
    logDebug('ForegroundServiceManager inicializado');
  }

  Future<void> startService() async {
    if (!_initialized) {
      await init();
    }
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) return;

    logDebug('Iniciando servicio foreground');
    await FlutterForegroundTask.startService(
      notificationTitle: 'Tracking activo',
      notificationText: 'La app está registrando tu ubicación',
      callback: startCallback,
    );
  }

  Future<void> stopService() async {
    if (await FlutterForegroundTask.isRunningService) {
      logDebug('Deteniendo servicio foreground');
      await FlutterForegroundTask.stopService();
    }
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

class LocationTaskHandler extends TaskHandler {
  final Battery _battery = Battery();

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    logDebug('Foreground task iniciado');
    await _updateNotification();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    logDebug('Foreground task tick ${timestamp.toIso8601String()}');
    await _updateNotification();
  }

  Future<void> _updateNotification() async {
    int? batteryLevel;
    try {
      batteryLevel = await _battery.batteryLevel;
    } catch (_) {}

    logDebug(
      'Actualizando notificación foreground',
      details: batteryLevel != null ? 'battery=$batteryLevel' : 'battery=?',
    );
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Tracking activo',
      notificationText: batteryLevel != null
          ? 'Batería: $batteryLevel%'
          : 'Registrando ubicación en background',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {}

  @override
  void onButtonPressed(String id) {
    if (id == 'stop') {
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }
}
