import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/restaurant_user.dart';

/// Production-Grade Supabase Authentication Service
///
/// Handles:
/// - Email/Password registration with restaurant metadata
/// - Email/Password authentication
/// - OAuth (Google, Apple) with PKCE
/// - Passwordless Magic Links / OTP
/// - Automatic & Manual Refresh Token Rotation
/// - Real-time Auth State Stream
/// - Diagnostics & Diagnostics Health Checks
class SupabaseAuthService {
  SupabaseAuthService._();
  static final SupabaseAuthService instance = SupabaseAuthService._();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  SupabaseClient? _client;
  SupabaseClient get client {
    if (_client == null) {
      try {
        _client = Supabase.instance.client;
      } catch (_) {
        throw StateError(
          'Supabase is not initialized. Call SupabaseAuthService.instance.initialize() first.',
        );
      }
    }
    return _client!;
  }

  /// Initialize Supabase with PKCE Auth Flow and secure auto-refresh
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        publishableKey: SupabaseConfig.supabasePublishableKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce, // RFC 7636 PKCE standard
          autoRefreshToken: true,
        ),
      );
      _client = Supabase.instance.client;
      _isInitialized = true;
      debugPrint('[SupabaseAuth] Initialized successfully with PKCE.');
    } catch (e) {
      debugPrint('[SupabaseAuth] Initialization error: $e');
      // Still set initialized state so the app doesn't crash if offline
      _isInitialized = false;
      rethrow;
    }
  }

  /// Real-time stream of the authenticated user
  Stream<RestaurantUser?> get authStateChanges {
    try {
      return client.auth.onAuthStateChange.map((data) {
        final user = data.session?.user;
        return user != null ? RestaurantUser.fromSupabaseUser(user) : null;
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Currently authenticated user, or null if unauthenticated
  RestaurantUser? get currentUser {
    try {
      final user = client.auth.currentUser;
      return user != null ? RestaurantUser.fromSupabaseUser(user) : null;
    } catch (_) {
      return null;
    }
  }

  /// Current active Supabase session
  Session? get currentSession {
    try {
      return client.auth.currentSession;
    } catch (_) {
      return null;
    }
  }

  /// Sign Up a new restaurant account with metadata
  Future<RestaurantUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String restaurantName,
    required String ownerName,
    required String phone,
  }) async {
    try {
      final res = await client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'restaurant_name': restaurantName.trim(),
          'owner_name': ownerName.trim(),
          'phone': phone.trim(),
        },
      );

      final user = res.user;
      if (user == null) {
        throw const AuthException('Registration failed: no user returned.');
      }

      return RestaurantUser.fromSupabaseUser(user);
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      debugPrint('[SupabaseAuth] signUp error: $e');
      throw 'Registration failed. Please check your network and try again.';
    }
  }

  /// Sign In with Email and Password
  Future<RestaurantUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final res = await client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final user = res.user;
      if (user == null) {
        throw const AuthException('Sign in failed: invalid credentials.');
      }

      return RestaurantUser.fromSupabaseUser(user);
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      debugPrint('[SupabaseAuth] signIn error: $e');
      throw 'Sign in failed. Please verify your credentials and network connection.';
    }
  }

  /// Sign In with Google via Supabase OAuth (PKCE)
  Future<void> signInWithGoogle() async {
    try {
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : SupabaseConfig.redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      debugPrint('[SupabaseAuth] Google OAuth error: $e');
      throw 'Google sign-in failed. Please try again.';
    }
  }

  /// Sign In using Google ID Token (Native Google Sign-In integration)
  Future<RestaurantUser> signInWithGoogleIdToken({
    required String idToken,
    String? accessToken,
  }) async {
    try {
      final res = await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      final user = res.user;
      if (user == null) {
        throw const AuthException('Google Sign-In failed: no user returned.');
      }
      return RestaurantUser.fromSupabaseUser(user);
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      debugPrint('[SupabaseAuth] Google ID token error: $e');
      throw 'Google Sign-In failed. Please try again.';
    }
  }

  /// Send a Magic Link (Passwordless OTP) to the user's email
  Future<void> sendMagicLink(String email) async {
    try {
      await client.auth.signInWithOtp(
        email: email.trim().toLowerCase(),
        emailRedirectTo: kIsWeb ? null : SupabaseConfig.redirectUrl,
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      debugPrint('[SupabaseAuth] Magic link error: $e');
      throw 'Could not send magic link. Please try again.';
    }
  }

  /// Send a Password Reset link
  Future<void> sendPasswordReset(String email) async {
    try {
      await client.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: kIsWeb ? null : '${SupabaseConfig.callbackUrlScheme}://reset-callback',
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      debugPrint('[SupabaseAuth] Password reset error: $e');
      throw 'Could not send password reset email. Please try again.';
    }
  }

  /// Manually force a session refresh (Tests Refresh Token Rotation)
  Future<Session?> refreshSession() async {
    try {
      final res = await client.auth.refreshSession();
      return res.session;
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      debugPrint('[SupabaseAuth] Session refresh error: $e');
      throw 'Failed to refresh authentication session.';
    }
  }

  /// Sign Out the current user and destroy the active session
  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      debugPrint('[SupabaseAuth] Sign out error: $e');
    }
  }

  /// Run real-time diagnostics on the Supabase connectivity
  Future<Map<String, dynamic>> checkDiagnostics() async {
    final results = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'url': SupabaseConfig.supabaseUrl,
      'project_ref': SupabaseConfig.projectRef,
      'is_initialized': _isInitialized,
    };

    try {
      final session = currentSession;
      results['session_active'] = session != null;
      if (session != null) {
        results['user_id'] = session.user.id;
        results['email'] = session.user.email;
        results['token_expires_at'] = session.expiresAt != null
            ? DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)
                .toIso8601String()
            : 'unknown';
        results['access_token_preview'] =
            '${session.accessToken.substring(0, 15)}...';
      }
      results['status'] = 'OK';
    } catch (e) {
      results['status'] = 'ERROR';
      results['error_details'] = e.toString();
    }

    return results;
  }

  /// Maps technical Supabase Auth errors into human-friendly explanations
  String _mapAuthException(AuthException e) {
    final msg = e.message.toLowerCase();

    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid claim') ||
        msg.contains('bad credentials')) {
      return 'Invalid email or password. Please verify your credentials.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('email already in use')) {
      return 'An account with this email address already exists.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please confirm your email address before logging in.';
    }
    if (msg.contains('rate limit') || msg.contains('too many requests')) {
      return 'Too many login attempts. Please wait a few moments and try again.';
    }
    if (msg.contains('password should be at least')) {
      return 'Password is too weak. Please use at least 6 characters.';
    }

    return e.message;
  }
}
