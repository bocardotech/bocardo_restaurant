import 'package:flutter/foundation.dart';
import 'supabase_auth_service.dart';
import '../models/restaurant_user.dart';

/// Facade Authentication Service for Bocardo Restaurant
///
/// Seamlessly bridges the existing application pages to [SupabaseAuthService],
/// providing real-time production authentication with enterprise fallback support.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final SupabaseAuthService _supabaseAuth = SupabaseAuthService.instance;

  // Local fallback cache in case of offline development
  final Map<String, _Account> _mockAccounts = {};
  _Account? _mockCurrent;

  /// Returns the current restaurant name from Supabase or active session
  String? get restaurantName {
    final supabaseUser = _supabaseAuth.currentUser;
    if (supabaseUser != null && supabaseUser.restaurantName.isNotEmpty) {
      return supabaseUser.restaurantName;
    }
    return _mockCurrent?.restaurantName;
  }

  /// Returns the strongly-typed authenticated user
  RestaurantUser? get currentUser => _supabaseAuth.currentUser;

  /// Sign In with Email & Password
  Future<void> signIn(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Attempt Supabase Authentication if initialized
    if (_supabaseAuth.isInitialized) {
      try {
        debugPrint('[AuthService] Attempting Supabase signIn for $cleanEmail');
        final user = await _supabaseAuth.signInWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );
        debugPrint('[AuthService] Supabase signIn succeeded: ${user.id}');
        return;
      } catch (e) {
        debugPrint('[AuthService] Supabase signIn error: $e');
        // If it's a genuine invalid credentials error, throw it directly
        final err = e.toString().toLowerCase();
        if (err.contains('invalid email or password') ||
            err.contains('bad credentials') ||
            err.contains('rate limit')) {
          rethrow;
        }
        // If network/connection failed, check if mock account exists for offline preview
        if (_mockAccounts.containsKey(cleanEmail)) {
          debugPrint('[AuthService] Falling back to local offline mock account');
          final account = _mockAccounts[cleanEmail];
          if (account != null && account.password == password) {
            _mockCurrent = account;
            return;
          }
        }
        rethrow;
      }
    }

    // 2. Offline / Mock fallback when Supabase is not yet initialized
    await Future.delayed(const Duration(milliseconds: 600));
    final account = _mockAccounts[cleanEmail];
    if (account == null || account.password != password) {
      throw 'Email or password is incorrect.';
    }
    _mockCurrent = account;
  }

  /// Sign Up a new restaurant account with full metadata
  Future<void> signUp({
    required String restaurantName,
    required String ownerName,
    required String phone,
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Attempt Supabase Registration if initialized
    if (_supabaseAuth.isInitialized) {
      try {
        debugPrint('[AuthService] Attempting Supabase signUp for $cleanEmail');
        final user = await _supabaseAuth.signUpWithEmailAndPassword(
          email: cleanEmail,
          password: password,
          restaurantName: restaurantName,
          ownerName: ownerName,
          phone: phone,
        );
        debugPrint('[AuthService] Supabase signUp succeeded: ${user.id}');
        return;
      } catch (e) {
        debugPrint('[AuthService] Supabase signUp error: $e');
        final err = e.toString().toLowerCase();
        if (err.contains('already exists') || err.contains('too weak')) {
          rethrow;
        }
        // If network issue, cache in mock accounts
        _mockAccounts[cleanEmail] = _Account(
          restaurantName.trim(),
          ownerName.trim(),
          phone.trim(),
          password,
        );
        _mockCurrent = _mockAccounts[cleanEmail];
        rethrow;
      }
    }

    // 2. Offline / Mock fallback
    await Future.delayed(const Duration(milliseconds: 600));
    if (_mockAccounts.containsKey(cleanEmail)) {
      throw 'An account with this email already exists.';
    }
    final account = _Account(
      restaurantName.trim(),
      ownerName.trim(),
      phone.trim(),
      password,
    );
    _mockAccounts[cleanEmail] = account;
    _mockCurrent = account;
  }

  /// Sign Out and destroy the active session
  Future<void> signOut() async {
    _mockCurrent = null;
    if (_supabaseAuth.isInitialized) {
      await _supabaseAuth.signOut();
    }
  }
}

class _Account {
  _Account(this.restaurantName, this.ownerName, this.phone, this.password);
  final String restaurantName;
  final String ownerName;
  final String phone;
  final String password;
}