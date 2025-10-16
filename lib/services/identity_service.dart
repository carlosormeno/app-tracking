import 'package:firebase_auth/firebase_auth.dart';

class IdentityService {
  IdentityService._internal();
  static final IdentityService instance = IdentityService._internal();
  factory IdentityService() => instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  String? get uid => currentUser?.uid;

  String? get email => currentUser?.email;

  bool get isSignedIn => currentUser != null;

  Future<String?> getIdToken() async {
    return await currentUser?.getIdToken();
  }
}
