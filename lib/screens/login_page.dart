import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';
import '../services/supabase_auth_service.dart';
import '../themes/brand.dart';

class LoginPage extends StatefulWidget {
const LoginPage({super.key});

@override
State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _hide = true;
  bool _loading = false;
  String? _error;

  Future<void>? _googleSignInInitialization;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  String _friendly(Object error) {
    final message = error
        .toString()
        .replaceFirst(
      RegExp(r'^(Exception|Error):\s*'),
      '',
    );

    return message.isEmpty
        ? 'Something went wrong. Please try again.'
        : message;
  }

  Future<void> _signInWithGoogle() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      debugPrint('GOOGLE LOGIN: Starting sign-in');

      await (_googleSignInInitialization ??=
          GoogleSignIn.instance.initialize());

      debugPrint('GOOGLE LOGIN: Initialization successful');

      final googleUser =
      await GoogleSignIn.instance.authenticate();

      debugPrint(
        'GOOGLE LOGIN: Account selected: ${googleUser.email}',
      );

      final googleAuth = googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw Exception(
          'Google ID token was not received. '
              'Check your Firebase and Google configuration.',
        );
      }

      debugPrint('GOOGLE LOGIN: ID token received');

      // 1. Authenticate with Supabase if initialized
      if (SupabaseAuthService.instance.isInitialized) {
        try {
          await SupabaseAuthService.instance.signInWithGoogleIdToken(
            idToken: googleAuth.idToken!,
          );
          debugPrint('GOOGLE LOGIN: Supabase authentication successful');
        } catch (e) {
          debugPrint('GOOGLE LOGIN: Supabase auth warning: $e');
        }
      }

      // 2. Also authenticate with Firebase if configured
      try {
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
        debugPrint('GOOGLE LOGIN: Firebase authentication successful');
      } catch (e) {
        debugPrint('GOOGLE LOGIN: Firebase auth warning: $e');
      }

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (route) => false,
      );
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint('GOOGLE LOGIN: Firebase error: ${e.code}');
      debugPrint('GOOGLE LOGIN: ${e.message}');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _error = _firebaseErrorMessage(e);
      });
    } on GoogleSignInException catch (e, stackTrace) {
      debugPrint('GOOGLE LOGIN: Google error: ${e.code}');
      debugPrint('GOOGLE LOGIN: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _error = e.code == GoogleSignInExceptionCode.canceled
            ? 'Google sign-in was cancelled.'
            : 'Google sign-in failed. Please try again.';
      });
    } catch (e, stackTrace) {
      debugPrint('GOOGLE LOGIN: Unexpected error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _error = _friendly(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _firebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email. '
            'Try your original sign-in method.';

      case 'network-request-failed':
        return 'Network error. Check your internet connection.';

      case 'operation-not-allowed':
        return 'Google sign-in is not enabled in Firebase Authentication.';

      case 'invalid-credential':
        return 'Google authentication failed. Check your Firebase configuration.';

      case 'user-disabled':
        return 'This account has been disabled.';

      default:
        return e.message ?? 'Google sign-in failed. Please try again.';
    }
  }

  Future<void> _submit() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.instance.signIn(
        _email.text.trim(),
        _password.text,
      );

      TextInput.finishAutofillContext();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
            (route) => false,
      );
    } catch (e, stackTrace) {
      debugPrint('EMAIL LOGIN ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        setState(() {
          _error = _friendly(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme
        .of(context)
        .colorScheme;
    final text = Theme
        .of(context)
        .textTheme;

    return AuthShell(
      title: 'Welcome back',
      subtitle: 'Log in to manage your menu and orders.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                enabled: !_loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                enableSuggestions: false,
                decoration: fieldDeco(
                  'Email',
                  Icons.mail_outline,
                ),
                onFieldSubmitted: (_) {
                  _passwordFocus.requestFocus();
                },
                validator: (value) {
                  final email = value?.trim() ?? '';

                  if (email.isEmpty) {
                    return 'Enter your email';
                  }

                  return RegExp(
                    r'^\S+@\S+\.\S+$',
                  ).hasMatch(email)
                      ? null
                      : 'Enter a valid email address';
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _password,
                focusNode: _passwordFocus,
                enabled: !_loading,
                obscureText: _hide,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                decoration: fieldDeco(
                  'Password',
                  Icons.lock_outline,
                  suffix: IconButton(
                    tooltip: _hide
                        ? 'Show password'
                        : 'Hide password',
                    icon: Icon(
                      _hide
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: _loading
                        ? null
                        : () {
                      setState(() {
                        _hide = !_hide;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter your password';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),

              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _error == null
                    ? const SizedBox(
                  width: double.infinity,
                )
                    : Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 20,
                            color: scheme.onErrorContainer,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: text.bodyMedium?.copyWith(
                                color: scheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: btnLabel(_loading, 'Log in'),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _signInWithGoogle,
                  icon: const Icon(
                    Icons.g_mobiledata,
                    size: 30,
                  ),
                  label: const Text('Continue with Google'),
                ),
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    child: Text(
                      'New here?',
                      style: text.bodySmall,
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () {
                    Navigator.pushNamed(
                      context,
                      '/signup',
                    );
                  },
                  child: const Text(
                    'Create a restaurant account',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/auth-test-bench');
                },
                icon: const Icon(Icons.science_outlined, size: 18),
                label: const Text('Open Supabase Auth Test Bench'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}