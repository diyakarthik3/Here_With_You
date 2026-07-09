import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthUserData {
  final String uid;
  final String name;
  final String email;
  final String role;

  const AuthUserData({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
  });
}

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<AuthUserData> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final credentials = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credentials.user!.uid;
    final normalizedEmail = email.trim().toLowerCase();

    await _firestore.collection('users').doc(uid).set({
      'name': name.trim(),
      'email': normalizedEmail,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return AuthUserData(
      uid: uid,
      name: name.trim(),
      email: normalizedEmail,
      role: role,
    );
  }

  Future<AuthUserData> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final credentials = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credentials.user!.uid;
    Map<String, dynamic>? data;

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      data = doc.data();
    } catch (_) {
      // Allow login to proceed even if Firestore role/profile fetch fails.
      data = null;
    }

    final role = (data?['role'] as String?) ?? 'user';
    final name = (data?['name'] as String?) ?? credentials.user?.displayName ?? 'User';
    final savedEmail = (data?['email'] as String?) ?? credentials.user?.email ?? email.trim().toLowerCase();

    return AuthUserData(
      uid: uid,
      name: name,
      email: savedEmail,
      role: role,
    );
  }

  Future<void> signOut() => _auth.signOut();
}
