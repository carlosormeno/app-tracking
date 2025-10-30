// import 'package:firebase_auth/firebase_auth.dart'; // Comentado: migrando a SAA
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';
import 'map_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      // Stream<UserSession?>
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const MapScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
