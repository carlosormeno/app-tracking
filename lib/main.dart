import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';
import 'services/auth_service.dart';
import 'services/foreground_service_manager.dart';
import 'utils/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  logDebug('Inicializando servicios foreground');
  await ForegroundServiceManager.instance.init();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    logDebug('Firebase inicializado correctamente');
  } catch (e, stack) {
    logError('Error inicializando Firebase', error: e, stackTrace: stack);
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
      home: StreamBuilder<User?>(
        stream: AuthService().authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return const MapScreen();
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
