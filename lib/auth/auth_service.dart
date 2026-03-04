
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

// Custom error class — shows friendly messages instead of Firebase codes
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}

// 3 possible states for an email — professional level detection
enum EmailStatus {
  newUser,        // never signed up before
  existingEmail,  // signed up with email + password
  existingGoogle, // signed up with Google Sign-In
}

class AuthService {
  final FirebaseAuth      _auth   = FirebaseAuth.instance;
  final FirebaseFirestore _db     = FirebaseFirestore.instance;
  final GoogleSignIn      _google = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ── Check email status ────────────────────────────────────────
  // Checks Firestore to determine if email is new, email user, or google user
  Future<EmailStatus> checkEmail(String email) async {
    try {
      // Check Firestore directly — 100% reliable
      final doc = await _db
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (doc.docs.isNotEmpty) {
        // Email found — check which provider they used
        final provider = doc.docs.first.data()['provider'] ?? 'email';

        if (provider == 'google') {
          return EmailStatus.existingGoogle; // → show Google button hint
        }
        return EmailStatus.existingEmail; // → show password field
      }

      // Email not in Firestore → new user
      return EmailStatus.newUser;
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException('Could not check email. Please try again.');
    }
  }

  // ── Register new user with email + password ───────────────────
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await result.user?.updateDisplayName(name);
      await result.user?.reload();

      final userModel = UserModel(
        uid:      result.user!.uid,
        name:     name,
        email:    email,
        photoUrl: '',
        provider: 'email',
      );

      await _saveUserToFirestore(userModel);
      return userModel;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_errorMessage(e.code));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Sign up failed. Please try again.');
    }
  }

  // ── Login existing user with email + password ─────────────────
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _db
          .collection('users')
          .doc(result.user?.uid)
          .update({'lastLoginAt': FieldValue.serverTimestamp()});

      final doc = await _db
          .collection('users')
          .doc(result.user?.uid)
          .get();

      return UserModel.fromMap(doc.data() ?? {});
    } on FirebaseAuthException catch (e) {
      throw AuthException(_errorMessage(e.code));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Sign in failed. Please try again.');
    }
  }

  // ── Login with Google ─────────────────────────────────────────
  Future<UserModel?> signInWithGoogle() async {
    try {
      final googleUser = await _google.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);

      final userModel = UserModel(
        uid:      result.user!.uid,
        name:     result.user?.displayName ?? '',
        email:    result.user?.email       ?? '',
        photoUrl: result.user?.photoURL    ?? '',
        provider: 'google',
      );

      await _saveUserToFirestore(userModel);
      return userModel;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_errorMessage(e.code));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Google Sign-In failed. Please try again.');
    }
  }

  // ── Send password reset email ─────────────────────────────────
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_errorMessage(e.code));
    }
  }

  // ── Sign out ──────────────────────────────────────────────────
  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }

  // ── Save user to Firestore ────────────────────────────────────
  Future<void> _saveUserToFirestore(UserModel user) async {
    final ref = _db.collection('users').doc(user.uid);
    final doc = await ref.get();

    if (!doc.exists) {
      await ref.set({
        ...user.toMap(),
        'createdAt':   FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.update({'lastLoginAt': FieldValue.serverTimestamp()});
    }
  }

  // ── Firebase error codes → readable messages ──────────────────
  String _errorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Try signing in.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}