import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../services/supabase_auth_service.dart';
import '../themes/brand.dart';

class AuthTestBenchPage extends StatefulWidget {
  const AuthTestBenchPage({super.key});

  @override
  State<AuthTestBenchPage> createState() => _AuthTestBenchPageState();
}

class _AuthTestBenchPageState extends State<AuthTestBenchPage> {
  final _emailController = TextEditingController(text: 'test.partner@example.com');
  final _passwordController = TextEditingController(text: 'TestSecurePassword123!');
  final _restaurantController = TextEditingController(text: 'Bocardo Bistro');
  final _ownerController = TextEditingController(text: 'Chef Mario');
  final _phoneController = TextEditingController(text: '+1234567890');

  bool _loading = false;
  String? _statusMessage;
  bool _isError = false;

  final List<String> _eventLogs = [];

  @override
  void initState() {
    super.initState();
    _logEvent('Test bench loaded. Supabase URL: ${SupabaseConfig.supabaseUrl}');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _restaurantController.dispose();
    _ownerController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _logEvent(String message) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _eventLogs.insert(0, '[$time] $message');
      if (_eventLogs.length > 50) _eventLogs.removeLast();
    });
  }

  void _setMessage(String message, {bool isError = false}) {
    setState(() {
      _statusMessage = message;
      _isError = isError;
    });
  }

  Future<void> _runDiagnostics() async {
    setState(() => _loading = true);
    _logEvent('Running diagnostics check...');
    try {
      final diag = await SupabaseAuthService.instance.checkDiagnostics();
      _logEvent('Diagnostics: ${jsonEncode(diag)}');
      _setMessage('Diagnostics passed: ${diag['status']}', isError: false);
    } catch (e) {
      _logEvent('Diagnostics error: $e');
      _setMessage('Diagnostics error: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testSignUp() async {
    setState(() => _loading = true);
    _logEvent('Testing Sign Up for ${_emailController.text}...');
    try {
      final user = await SupabaseAuthService.instance.signUpWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
        restaurantName: _restaurantController.text,
        ownerName: _ownerController.text,
        phone: _phoneController.text,
      );
      _logEvent('Sign Up Success! User ID: ${user.id}, Restaurant: ${user.restaurantName}');
      _setMessage('Sign Up Successful for ${user.email}!', isError: false);
    } catch (e) {
      _logEvent('Sign Up Failed: $e');
      _setMessage('Sign Up Error: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testSignIn() async {
    setState(() => _loading = true);
    _logEvent('Testing Sign In for ${_emailController.text}...');
    try {
      final user = await SupabaseAuthService.instance.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      _logEvent('Sign In Success! User ID: ${user.id}, Email: ${user.email}');
      _setMessage('Sign In Successful: Welcome back!', isError: false);
    } catch (e) {
      _logEvent('Sign In Failed: $e');
      _setMessage('Sign In Error: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testMagicLink() async {
    setState(() => _loading = true);
    _logEvent('Testing Magic Link for ${_emailController.text}...');
    try {
      await SupabaseAuthService.instance.sendMagicLink(_emailController.text);
      _logEvent('Magic link OTP email dispatched!');
      _setMessage('Magic link sent to ${_emailController.text}', isError: false);
    } catch (e) {
      _logEvent('Magic Link Failed: $e');
      _setMessage('Magic Link Error: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testPasswordReset() async {
    setState(() => _loading = true);
    _logEvent('Testing Password Reset for ${_emailController.text}...');
    try {
      await SupabaseAuthService.instance.sendPasswordReset(_emailController.text);
      _logEvent('Password reset email dispatched!');
      _setMessage('Password reset email dispatched!', isError: false);
    } catch (e) {
      _logEvent('Password Reset Failed: $e');
      _setMessage('Password Reset Error: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testRefreshSession() async {
    setState(() => _loading = true);
    _logEvent('Testing Refresh Token Rotation...');
    try {
      final session = await SupabaseAuthService.instance.refreshSession();
      if (session != null) {
        _logEvent('Token Rotated! New Access Token preview: ${session.accessToken.substring(0, 15)}...');
        _setMessage('Session refreshed & token rotated successfully!', isError: false);
      } else {
        _logEvent('No active session to rotate.');
        _setMessage('No active session to refresh.', isError: true);
      }
    } catch (e) {
      _logEvent('Session Refresh Failed: $e');
      _setMessage('Refresh Error: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testSignOut() async {
    setState(() => _loading = true);
    _logEvent('Signing out...');
    try {
      await SupabaseAuthService.instance.signOut();
      _logEvent('Signed out successfully.');
      _setMessage('Signed out successfully.', isError: false);
    } catch (e) {
      _logEvent('Sign Out Error: $e');
      _setMessage('Sign Out Error: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseAuthService.instance.currentUser;
    final session = SupabaseAuthService.instance.currentSession;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F7F9),
      appBar: AppBar(
        title: const Text('Supabase Auth Test Bench'),
        backgroundColor: Brand.ink,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Run Diagnostics',
            onPressed: _loading ? null : _runDiagnostics,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Banner
            if (_statusMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isError ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isError ? Colors.red.shade300 : Colors.green.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isError ? Icons.error_outline : Icons.check_circle_outline,
                      color: _isError ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _isError ? Colors.red.shade900 : Colors.green.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Live Session Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'LIVE SESSION STATE',
                          style: theme.textTheme.labelMedium?.copyWith(
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                            color: Brand.cyanDark,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: session != null ? Colors.green.shade100 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            session != null ? 'AUTHENTICATED' : 'UNAUTHENTICATED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: session != null ? Colors.green.shade800 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    if (user != null) ...[
                      _sessionRow('User ID', user.id),
                      _sessionRow('Email', user.email),
                      _sessionRow('Restaurant', user.restaurantName),
                      _sessionRow('Owner', user.ownerName),
                      _sessionRow('Phone', user.phone),
                      _sessionRow('Role', user.role),
                      if (session != null && session.expiresAt != null)
                        _sessionRow(
                          'Expires',
                          DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)
                              .toLocal()
                              .toString(),
                        ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No user is currently authenticated.',
                          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Form Inputs
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TEST CREDENTIALS & PAYLOAD',
                      style: theme.textTheme.labelMedium?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: Brand.cyanDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Test Email', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _restaurantController,
                      decoration: const InputDecoration(labelText: 'Restaurant Name', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ownerController,
                            decoration: const InputDecoration(labelText: 'Owner Name', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            decoration: const InputDecoration(labelText: 'Phone', isDense: true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons Grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _loading ? null : _testSignIn,
                  icon: const Icon(Icons.login),
                  label: const Text('Test Sign In'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _loading ? null : _testSignUp,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Test Sign Up'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _testRefreshSession,
                  icon: const Icon(Icons.autorenew),
                  label: const Text('Rotate Refresh Token'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _testMagicLink,
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Send Magic Link'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _testPasswordReset,
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Password Reset'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade100,
                    foregroundColor: Colors.red.shade900,
                  ),
                  onPressed: _loading ? null : _testSignOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Live Event Console
            Card(
              color: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'EVENT CONSOLE',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.1,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear_all, size: 18, color: Colors.white70),
                          tooltip: 'Clear Console',
                          onPressed: () => setState(() => _eventLogs.clear()),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        itemCount: _eventLogs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              _eventLogs[index],
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF555555),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
