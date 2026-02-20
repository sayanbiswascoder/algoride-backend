import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Singleton authentication service wrapping Firebase Auth.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Currently signed-in user (null if signed out).
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes — used by the StreamBuilder in main.dart.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─────────────────────────────────────────────────────────────────────────
  // EMAIL / PASSWORD
  // ─────────────────────────────────────────────────────────────────────────

  /// Sign in with email and password.
  Future<UserCredential> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential;
  }

  /// Create a new account with email and password, then set display name
  /// and create a Firestore user document.
  Future<UserCredential> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Set display name
    await credential.user?.updateDisplayName(displayName.trim());

    // Create Firestore user doc
    if (credential.user != null) {
      await _db.collection('users').doc(credential.user!.uid).set({
        'email': email.trim(),
        'displayName': displayName.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return credential;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GOOGLE SIGN-IN
  // ─────────────────────────────────────────────────────────────────────────

  /// Sign in (or sign up) with Google.
  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'sign-in-cancelled',
        message: 'Google sign-in was cancelled.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);

    // Ensure Firestore user doc exists
    if (userCredential.user != null) {
      final docRef = _db.collection('users').doc(userCredential.user!.uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set({
          'email': userCredential.user!.email,
          'displayName': userCredential.user!.displayName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    return userCredential;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SIGN OUT
  // ─────────────────────────────────────────────────────────────────────────

  /// Sign out of both Firebase and Google.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}

/// Custom exception for auth-related errors.
class FirebaseAuthException implements Exception {
  final String code;
  final String message;
  const FirebaseAuthException({required this.code, required this.message});

  @override
  String toString() => message;
}
