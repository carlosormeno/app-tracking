import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../utils/logger.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isRegisterMode = false; // Comentado conceptualmente: SSO no registra
  bool _isLoading = false;
  String? _errorMessage;
  bool _showPassword = false;
  bool _rememberUser = false;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadRememberedUser();
  }

  Future<void> _loadRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_user') ?? false;
    String? usuario;
    if (remember) {
      usuario = prefs.getString('remembered_usuario');
    }
    if (mounted) {
      setState(() {
        _rememberUser = remember;
        if (usuario != null && usuario.isNotEmpty) {
          _usuarioController.text = usuario;
        }
      });
    } else {
      _rememberUser = remember;
      if (usuario != null && usuario.isNotEmpty) {
        _usuarioController.text = usuario;
      }
    }
  }

  Future<void> _persistRememberPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_user', value);
    if (!value) {
      // Si el usuario desactiva "Recordar", limpiar email almacenado
      await prefs.remove('remembered_usuario');
    }
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final usuario = _usuarioController.text.trim();
    final password = _passwordController.text.trim();

    if (usuario.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Ingresa usuario y contraseña');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Autenticación SAA (codigoSistema en duro)
      logDebug('Iniciando sesión en SAA', details: usuario);
      await _authService.signInSaa(usuario: usuario, contrasena: password);

      // Persistir preferencia de recordar usuario
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_user', _rememberUser);
      if (_rememberUser) {
        await prefs.setString('remembered_usuario', usuario);
      } else {
        await prefs.remove('remembered_usuario');
      }

      // Mostrar token obtenido (vista previa truncada)
      final token = AuthService().currentSession?.token;
      if (mounted && token != null && token.isNotEmpty) {
        final preview = token.length > 40 ? '${token.substring(0, 40)}…' : token;
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Token SAA obtenido: $preview')),
        );
      }
    } on Exception catch (e) {
      logError('Error en autenticación', error: e);
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar sesión'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
            TextField(
              controller: _usuarioController,
              decoration: const InputDecoration(labelText: 'Usuario'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: !_showPassword,
              decoration: const InputDecoration(labelText: 'Contraseña'),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Checkbox(
                  value: _showPassword,
                  onChanged: (v) {
                    setState(() => _showPassword = v ?? false);
                  },
                ),
                const Text('Ver contraseña'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Checkbox(
                  value: _rememberUser,
                  onChanged: (v) {
                    final newVal = v ?? false;
                    setState(() => _rememberUser = newVal);
                    // Guardar inmediatamente la preferencia de recordar
                    // (se mantiene tras cerrar sesión)
                    // No esperamos el Future para no bloquear la UI.
                    // ignore: discarded_futures
                    _persistRememberPreference(newVal);
                  },
                ),
                const Text('Recordar usuario'),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isRegisterMode ? 'Registrarme' : 'Ingresar'),
              ),
            ),
            // Registro deshabilitado: flujo SSO
          ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
