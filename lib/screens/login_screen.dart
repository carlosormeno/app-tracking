import 'package:flutter/material.dart';

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

  final AuthService _authService = AuthService();

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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña'),
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
  }
}
