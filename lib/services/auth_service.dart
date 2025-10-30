// import 'package:firebase_auth/firebase_auth.dart'; // Comentado: se migra a SAA
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

// Sesión de usuario basada en SAA
class UserSession {
  UserSession({
    required this.uid,
    required this.usuario,
    required this.token,
    this.email,
    this.permisos = const <String>[],
  });

  final String uid; // Claim `sub` del JWT SAA
  final String usuario; // Claim `Usuario` o input
  final String token; // JWT SAA
  final String? email; // Puede provenir de claims o derivarse
  final List<String> permisos; // PerfilPermiso del JWT
}

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;
  // Código original Firebase (comentado para mantener secuencia)
  // final FirebaseAuth _auth = FirebaseAuth.instance;
  // Stream<User?> get authStateChanges => _auth.authStateChanges();
  // User? get currentUser => _auth.currentUser;
  // Future<void> signIn({required String email, required String password}) async {
  //   await _auth.signInWithEmailAndPassword(email: email, password: password);
  // }
  // Future<void> register({required String email, required String password}) async {
  //   await _auth.createUserWithEmailAndPassword(email: email, password: password);
  // }
  // Future<void> signOut() => _auth.signOut();
  // Future<String?> getIdToken() async => _auth.currentUser?.getIdToken();

  // ---- Implementación SAA ----
  static const String _saaUrl =
      'http://10.50.129.216:9080/appComponenteWeb/SAA/token/usuario/generar';
  static const String _saaLogoutUrl =
      'http://onpwasihsd01.onp.gob.pe/appComponenteWeb/SAA/token/cerrarSesion';

  final StreamController<UserSession?> _controller =
      StreamController<UserSession?>.broadcast();

  UserSession? _currentSession;

  // Importante: emitimos el estado actual primero para evitar pantallas esperando
  // cuando el listener se suscribe después de restoreSession().
  Stream<UserSession?> get authStateChanges async* {
    yield _currentSession;
    yield* _controller.stream;
  }

  UserSession? get currentSession => _currentSession;

  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final usuario = prefs.getString('auth_usuario');
      if (token != null &&
          token.isNotEmpty &&
          usuario != null &&
          usuario.isNotEmpty) {
        final claims = _decodeJwtClaims(token);
        final uid = _readString(claims, 'sub') ?? usuario;
        final email = _deriveEmail(claims: claims, usuario: usuario);
        final permisos = _extractPermisos(claims);
        _currentSession = UserSession(
          uid: uid,
          usuario: usuario,
          token: token,
          email: email,
          permisos: permisos,
        );
        _controller.add(_currentSession);
      } else {
        _controller.add(null);
      }
    } catch (e, st) {
      logError('Error restaurando sesión', error: e, stackTrace: st);
      _controller.add(null);
    }
  }

  Future<void> signInSaa({
    required String usuario,
    required String contrasena,
    String codigoSistema = '641', // Hardcode por ahora
  }) async {
    logDebug(
      'Autenticando contra SAA',
      details: 'usuario=$usuario sistema=$codigoSistema',
    );
    final response = await http
        .post(
          Uri.parse(_saaUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'usuario': usuario,
            'contrasena': contrasena,
            'codigoSistema': codigoSistema,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error SAA (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = (data['token'] as String?)?.trim();
    if (token == null || token.isEmpty) {
      throw Exception('Respuesta SAA sin token');
    }

    final claims = _decodeJwtClaims(token);
    final uid = _readString(claims, 'sub') ?? usuario;
    final usuarioClaim = _readString(claims, 'Usuario') ?? usuario;
    final email = _deriveEmail(claims: claims, usuario: usuarioClaim);
    final permisos = _extractPermisos(claims);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('auth_usuario', usuarioClaim);
    } catch (_) {}

    _currentSession = UserSession(
      uid: uid,
      usuario: usuarioClaim,
      token: token,
      email: email,
      permisos: permisos,
    );
    _controller.add(_currentSession);
    logDebug(
      'Token SAA obtenido (preview)',
      //details: token.substring(0, token.length > 24 ? 24 : token.length));
      details: token,
    );
    if (permisos.isNotEmpty) {
      logDebug(
        'Permisos SAA',
        details: '${permisos.length}: ${permisos.take(5).join(', ')}',
      );
    } else {
      logDebug('Permisos SAA vacíos o no presentes');
    }
  }

  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('auth_usuario');
    } catch (_) {}
    _currentSession = null;
    _controller.add(null);
  }

  // Cierra sesión en SAA enviando el token en el cuerpo.
  Future<LogoutResult> signOutSaa() async {
    final token = _currentSession?.token ?? await _loadSavedToken();
    if (token == null || token.isEmpty) {
      await signOut();
      return LogoutResult(resultado: '3', mensaje: 'El token debe ser distinto de vacío', success: false);
    }
    try {
      logDebug('Cerrando sesión SAA');
      final resp = await http
          .post(
            Uri.parse(_saaLogoutUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token}),
          )
          .timeout(const Duration(seconds: 10));
      String resultado = '';
      String mensaje = '';
      try {
        final json = jsonDecode(resp.body);
        if (json is Map<String, dynamic>) {
          final r = json['resultado'];
          final m = json['mensaje'];
          resultado = r?.toString() ?? '';
          mensaje = m?.toString() ?? '';
        } else {
          mensaje = 'Respuesta inesperada de SAA';
        }
      } catch (_) {
        mensaje = 'No se pudo parsear la respuesta de SAA';
      }
      final success = resultado == '1';
      if (success) {
        logDebug('Sesión SAA cerrada: $mensaje');
      } else {
        logError('Cierre SAA no exitoso', error: 'resultado=$resultado mensaje=$mensaje');
      }
      return LogoutResult(resultado: resultado.isEmpty ? '4' : resultado, mensaje: mensaje, success: success);
    } catch (e, st) {
      logError('Excepción cerrando sesión SAA', error: e, stackTrace: st);
      return LogoutResult(resultado: '4', mensaje: 'ERROR', success: false);
    } finally {
      await signOut();
    }
  }

  Future<String?> _loadSavedToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final t = prefs.getString('auth_token');
      return (t != null && t.isNotEmpty) ? t : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getIdToken() async => _currentSession?.token;

  // Utilidades
  Map<String, dynamic> _decodeJwtClaims(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return <String, dynamic>{};
    try {
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final bytes = base64Url.decode(normalized);
      final jsonStr = utf8.decode(bytes);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return map;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String? _readString(Map map, String key) {
    final v = map[key];
    if (v is String && v.isNotEmpty) return v;
    return null;
  }

  String _domainFromUsuario(String usuario) {
    // Dominio de prueba; ajustar más adelante
    return '${usuario.toLowerCase()}@saa.local';
  }

  String? _deriveEmail({
    required Map<String, dynamic> claims,
    required String usuario,
  }) {
    final email = _readString(claims, 'email') ?? _readString(claims, 'Email');
    return email ?? _domainFromUsuario(usuario);
  }

  List<String> _extractPermisos(Map<String, dynamic> claims) {
    final raw = claims['PerfilPermiso'];
    if (raw is! List) return const <String>[];

    final out = <String>[];
    for (final perfil in raw) {
      if (perfil is! Map) continue;
      final arr = perfil['arrPermisos'];
      if (arr is! List) continue;
      for (final perm in arr) {
        if (perm is! Map) continue;
        final noAccion = _readString(perm, 'noAccion');
        final idPermiso = _readString(perm, 'idPermiso');
        final noPermiso = _readString(perm, 'noPermiso');
        if (noAccion != null && noAccion.isNotEmpty) out.add(noAccion);
        if (idPermiso != null && idPermiso.isNotEmpty) out.add(idPermiso);
        if (noPermiso != null && noPermiso.isNotEmpty) out.add(noPermiso);
      }
    }

    // Deduplicar conservando orden
    final seen = <String>{};
    final dedup = <String>[];
    for (final s in out) {
      final t = s.trim();
      if (t.isEmpty) continue;
      if (seen.add(t)) dedup.add(t);
    }
    return dedup;
  }
}

class LogoutResult {
  LogoutResult({required this.resultado, required this.mensaje, required this.success});
  final String resultado; // "1".."6"
  final String mensaje;
  final bool success;
}
