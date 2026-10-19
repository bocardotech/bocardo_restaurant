import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/supabase_auth_service.dart';
import '../themes/brand.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _restaurant = TextEditingController();
  final _owner = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_restaurant, _owner, _phone, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  String _friendly(Object e) {
    final msg = e.toString().replaceFirst(RegExp(r'^(Exception|Error):\s*'), '');
    return msg.isEmpty ? 'Something went wrong. Please try again.' : msg;
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
      await AuthService.instance.signUp(
        restaurantName: _restaurant.text.trim(),
        ownerName: _owner.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      TextInput.finishAutofillContext();
      if (!mounted) return;

      // Check if session was automatically established (or requires email verification)
      final session = SupabaseAuthService.instance.currentSession;
      if (session != null) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      } else {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Account Created'),
            content: Text(
              'Your restaurant account for ${_restaurant.text.trim()} has been registered!\n\nIf email verification is enabled, please check your inbox at ${_email.text.trim()} before logging in.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                },
                child: const Text('Go to Login'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _required(String? v, String msg) =>
      (v == null || v.trim().isEmpty) ? msg : null;

  Widget _gap() => const SizedBox(height: 16);

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 12),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return AuthShell(
      showBack: true,
      title: 'Create your account',
      subtitle: 'Register your restaurant and start receiving orders.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _section('Restaurant details'),
              TextFormField(
                controller: _restaurant,
                enabled: !_loading,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.organizationName],
                decoration:
                fieldDeco('Restaurant name', Icons.storefront_outlined),
                validator: (v) => _required(v, 'Enter your restaurant name'),
              ),
              _gap(),
              TextFormField(
                controller: _owner,
                enabled: !_loading,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: fieldDeco('Owner name', Icons.person_outline),
                validator: (v) => _required(v, 'Enter the owner name'),
              ),
              _gap(),
              TextFormField(
                controller: _phone,
                enabled: !_loading,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
                  LengthLimitingTextInputFormatter(16),
                ],
                decoration: fieldDeco('Phone number', Icons.phone_outlined),
                validator: (v) =>
                (v ?? '').replaceAll(RegExp(r'\D'), '').length < 10
                    ? 'Enter a valid phone number'
                    : null,
              ),

              const SizedBox(height: 24),
              _section('Account details'),
              TextFormField(
                controller: _email,
                enabled: !_loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                enableSuggestions: false,
                decoration: fieldDeco('Email', Icons.mail_outline),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Enter your email';
                  return RegExp(r'^\S+@\S+\.\S+$').hasMatch(value)
                      ? null
                      : 'Enter a valid email address';
                },
              ),
              _gap(),
              TextFormField(
                controller: _password,
                enabled: !_loading,
                obscureText: _hide,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: fieldDeco(
                  'Password (6+ characters)',
                  Icons.lock_outline,
                  suffix: IconButton(
                    tooltip: _hide ? 'Show passwords' : 'Hide passwords',
                    icon: Icon(_hide
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
                validator: (v) => (v ?? '').length < 6
                    ? 'Password must be at least 6 characters'
                    : null,
              ),
              _gap(),
              TextFormField(
                controller: _confirm,
                enabled: !_loading,
                obscureText: _hide,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                decoration:
                fieldDeco('Confirm password', Icons.lock_reset_outlined),
                validator: (v) =>
                v != _password.text ? 'Passwords do not match' : null,
                onFieldSubmitted: (_) => _submit(),
              ),

              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _error == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline,
                              size: 20, color: scheme.onErrorContainer),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: text.bodyMedium?.copyWith(
                                  color: scheme.onErrorContainer),
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
                  child: btnLabel(_loading, 'Create account'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loading ? null : () => Navigator.pop(context),
                child: const Text('Already registered? Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}