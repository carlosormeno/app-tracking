// import 'package:firebase_auth/firebase_auth.dart'; // Comentado: usar SAA
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class IdentityService {
  IdentityService._internal();
  static final IdentityService instance = IdentityService._internal();
  factory IdentityService() => instance;

  // Implementación basada en SAA
  UserSession? get _session => AuthService().currentSession;

  String? get uid => _session?.uid;
  String? get email => _session?.email;
  bool get isSignedIn => _session != null;

  List<String> get permisos => _session?.permisos ?? const <String>[];
  bool hasPermiso(String codigo) {
    final target = codigo.toLowerCase();
    for (final p in permisos) {
      if (p.toLowerCase() == target) return true;
    }
    return false;
  }

  Future<String?> getIdToken() async {
    final s = _session;
    if (s != null) return s.token;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      return (token != null && token.isNotEmpty) ? token : null;
    } catch (_) {
      return null;
    }
  }
}
