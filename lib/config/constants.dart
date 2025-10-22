import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

class Constants {
  Constants._();

  /// Permite sobreescribir la URL del backend en tiempo de compilación
  /// usando `--dart-define=API_BASE_URL=...`.
  static const String _definedApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  /// Base URL del backend, ajustada según la plataforma y/o `--dart-define`.
  static String get apiBaseUrl {
    // Prioridad 1: valor provisto por --dart-define
    if (_definedApiBaseUrl.isNotEmpty) {
      return _definedApiBaseUrl;
    }

    // Prioridad 2: valores por defecto según plataforma/entorno
    if (kIsWeb) {
      return 'http://localhost:8080/api';
    }
    if (Platform.isAndroid) {
      // Emulador Android: 10.0.2.2 hace NAT hacia localhost de la máquina
      //return 'http://10.0.2.2:8080/api';
      //return 'http://172.20.10.2:8080/api';
      return 'http://192.168.137.1:8080/api'; //Para red compartida
    }
    return 'http://localhost:8080/api';
  }
}
