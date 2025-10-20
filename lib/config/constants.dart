import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

class Constants {
  Constants._();

  /// Base URL del backend, ajustada según la plataforma.
  static String get apiBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080/api';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080/api'; //Trabaja para el emulador
      //return 'http://172.20.10.2:8080/api';
      //return 'http://192.168.137.1:8080/api';  //Trabaja para la Wifi que comparte el equipo
      //otro cambios
    }
    return 'http://localhost:8080/api';
  }
}
