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
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isRegisterMode = false;
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
    String? email;
    if (remember) {
      email = prefs.getString('remembered_email');
    }
    if (mounted) {
      setState(() {
        _rememberUser = remember;
        if (email != null && email.isNotEmpty) {
          _emailController.text = email;
        }
      });
    } else {
      _rememberUser = remember;
      if (email != null && email.isNotEmpty) {
        _emailController.text = email;
      }
    }
  }

  Future<void> _persistRememberPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_user', value);
    if (!value) {
      // Si el usuario desactiva "Recordar", limpiar email almacenado
      await prefs.remove('remembered_email');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Ingresa email y contraseña');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isRegisterMode) {
        logDebug('Registrando usuario en Firebase', details: email);
        await _authService.register(email: email, password: password);
      } else {
        logDebug('Iniciando sesión en Firebase', details: email);
        await _authService.signIn(email: email, password: password);
      }

      // Persistir preferencia de recordar usuario y email
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_user', _rememberUser);
      if (_rememberUser) {
        await prefs.setString('remembered_email', email);
      } else {
        await prefs.remove('remembered_email');
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
        title: Text(_isRegisterMode ? 'Crear cuenta' : 'Iniciar sesión'),
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
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
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
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _isRegisterMode = !_isRegisterMode;
                        _errorMessage = null;
                      });
                    },
              child: Text(_isRegisterMode
                  ? '¿Ya tienes cuenta? Inicia sesión'
                  : 'Crear una cuenta nueva'),
            )
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
