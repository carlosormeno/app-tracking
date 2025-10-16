import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> register({required String email, required String password}) async {
    await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  Future<String?> getIdToken() async {
    return _auth.currentUser?.getIdToken();
  }
}
