// import 'package:firebase_auth/firebase_auth.dart'; // Comentado: se migra a SAA
// import 'package:firebase_core/firebase_core.dart'; // Comentado
import 'package:flutter/material.dart';

// import 'firebase_options.dart'; // Comentado mientras se prueba SAA
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/foreground_service_manager.dart';
import 'services/background_tasks.dart';
import 'package:workmanager/workmanager.dart';
import 'utils/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  logDebug('Inicializando servicios foreground');
  await ForegroundServiceManager.instance.init();
  // Inicializa tareas en background (WorkManager) para flush de cola offline
  try {
    await Workmanager().initialize(backgroundTaskDispatcher, isInDebugMode: false);
    await registerBackgroundTasks();
  } catch (e, stack) {
    logError('Error inicializando WorkManager', error: e, stackTrace: stack);
  }

  try {
    // Firebase.initializeApp(...) // Comentado temporalmente: usando SAA
    await AuthService().restoreSession();
    logDebug('Sesión SAA restaurada (si existía)');
  } catch (e, stack) {
    logError('Error restaurando sesión SAA', error: e, stackTrace: stack);
  }

  runApp(const LocationTrackerApp());
}

class LocationTrackerApp extends StatelessWidget {
  const LocationTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
