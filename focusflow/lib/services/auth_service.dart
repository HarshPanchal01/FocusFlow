import 'dart:async';

/// Placeholder service for Firebase Auth (Issue #4).
/// 
/// This mock simulates authentication delays and errors.
class AuthService {
  // Singleton instance
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Mock user state
  bool _isLoggedIn = false;
  String? _currentUserEmail;

  bool get isLoggedIn => _isLoggedIn;
  String? get currentUserEmail => _currentUserEmail;

  Future<void> signIn(String email, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));
    
    // Simulate simple validation
    if (password == 'fail') {
      throw Exception('Invalid password');
    }
    
    _isLoggedIn = true;
    _currentUserEmail = email;
  }

  Future<void> signInWithGoogle() async {
    await Future.delayed(const Duration(seconds: 1));
    _isLoggedIn = true;
    _currentUserEmail = 'google_user@gmail.com';
  }

  Future<void> signUp(String email, String password) async {
    await Future.delayed(const Duration(seconds: 2));
    if (email.contains('exists')) {
      throw Exception('Email already in use');
    }
    _isLoggedIn = true;
    _currentUserEmail = email;
  }

  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _isLoggedIn = false;
    _currentUserEmail = null;
  }
}
