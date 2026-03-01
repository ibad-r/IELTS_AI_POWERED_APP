import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

// Custom error class — shows friendly messages instead of Firebase codes
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}

// Tells us if an email belongs to a new or existing user
enum EmailStatus { newUser, existingUser }

class AuthService {
  // Firebase instances — created once, reused everywhere
  final FirebaseAuth      _auth   = FirebaseAuth.instance;
  final FirebaseFirestore _db     = FirebaseFirestore.instance;
  final GoogleSignIn      _google = GoogleSignIn();

  // Stream that app listens to — fires whenever login state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Currently logged in Firebase user (null if not logged in)
  User? get currentUser => _auth.currentUser;

  // ── Check if email is new or existing user ────────────────────
  // How it works: tries a fake login — Firebase tells us if user exists
  Future<EmailStatus> checkEmail(String email) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: '________DUMMY_CHECK________',
      );
      return EmailStatus.existingUser;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return EmailStatus.newUser;
      } else if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        return EmailStatus.existingUser;
      } else if (e.code == 'too-many-requests') {
        throw AuthException('Too many attempts. Please try again later.');
      }
      return EmailStatus.existingUser;
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
      // 1. Create account in Firebase Auth
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Set their display name
      await result.user?.updateDisplayName(name);
      await result.user?.reload();

      // 3. Build UserModel
      final userModel = UserModel(
        uid:      result.user!.uid,
        name:     name,
        email:    email,
        photoUrl: '',
        provider: 'email',
      );

      // 4. Save to Firestore
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
      // 1. Sign in with Firebase Auth
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Update last login time in Firestore
      await _db
          .collection('users')
          .doc(result.user?.uid)
          .update({'lastLoginAt': FieldValue.serverTimestamp()});

      // 3. Fetch and return UserModel from Firestore
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
      // 1. Open Google account picker
      final googleUser = await _google.signIn();
      if (googleUser == null) return null; // user cancelled

      // 2. Get Google credentials
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );

      // 3. Sign in to Firebase with Google credentials
      final result = await _auth.signInWithCredential(credential);

      // 4. Build UserModel
      final userModel = UserModel(
        uid:      result.user!.uid,
        name:     result.user?.displayName ?? '',
        email:    result.user?.email       ?? '',
        photoUrl: result.user?.photoURL    ?? '',
        provider: 'google',
      );

      // 5. Save to Firestore (only on first login)
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
    await _google.signOut(); // clear Google session
    await _auth.signOut();   // clear Firebase session
  }

  // ── Save user to Firestore (private helper) ───────────────────
  // If user already exists → only update lastLoginAt
  // If new user → save full profile
  Future<void> _saveUserToFirestore(UserModel user) async {
    final ref = _db.collection('users').doc(user.uid);
    final doc = await ref.get();

    if (!doc.exists) {
      // New user — save everything
      await ref.set({
        ...user.toMap(),
        'createdAt':   FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Returning user — just update login time
      await ref.update({'lastLoginAt': FieldValue.serverTimestamp()});
    }
  }

  // ── Convert Firebase error codes to readable messages ─────────
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