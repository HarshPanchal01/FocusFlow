import 'package:firebase_auth/firebase_auth.dart';

/// Firebase auth service for FocusFlow.
///
/// Supports:
/// - anonymous startup login
/// - email/password login + signup
/// - compatibility methods used by existing screens
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream for auth changes if needed later
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Used by settings screen
  bool get isLoggedIn => _auth.currentUser != null;

  /// Used to determine if user is anonymous 
  bool get isAuthenticated => _auth.currentUser != null;

  bool get isAnonymousUser => _auth.currentUser?.isAnonymous ?? false;

  bool get hasPermanentAccount =>
    _auth.currentUser != null && !(_auth.currentUser?.isAnonymous ?? true);

  String? get currentUserEmail => _auth.currentUser?.email;

  /// Anonymous sign-in for first app launch
  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  /// Main login method used by login_screen.dart
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Main signup method used by signup_screen.dart
  /// If current user is anonymous, link that account so task data stays.
  Future<UserCredential> signUp(String email, String password) async {
    final current = _auth.currentUser;

    if (current != null && current.isAnonymous) {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      return await current.linkWithCredential(credential);
    }

    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Optional explicit methods if you want to use them later
  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return await signIn(email, password);
  }

  Future<UserCredential> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return await signUp(email, password);
  }

  /// TEMP STUB
  /// Your login screen has a Google button, but Google auth is not set up yet.
  /// This avoids compile errors for now.
  Future<void> signInWithGoogle() async {
    throw UnimplementedError(
      'Google Sign-In is not set up yet in this project.',
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();

    // Optional: automatically create a new anonymous session after logout
    await _auth.signInAnonymously();
  }
}