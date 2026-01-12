import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Authentication state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // Sign in with Email and Password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Check if current user is admin
  Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      print("Checking admin role for UID: ${user.uid}");
      final doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        print("User document does NOT exist in Firestore for UID: ${user.uid}");
        return false;
      }

      final profile = UserProfile.fromFirestore(doc);
      print("User role found: ${profile.role}");
      return profile.role == 'admin';
    } catch (e) {
      print("Error checking admin role: $e");
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
