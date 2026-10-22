import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/daos/auth_dao.dart';
import '../../../database/database_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    required this.isInitialSetup,
    required this.onAuthenticated,
  });

  final bool isInitialSetup;
  final ValueChanged<AuthUser> onAuthenticated;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController(text: 'admin');
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _obscurePassword = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setup = widget.isInitialSetup;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 1,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.storefront_outlined,
                          size: 48, color: Color(0xFF2563EB)),
                      const SizedBox(height: 16),
                      Text(
                        setup ? 'Set up your shop account' : 'Welcome back',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        setup
                            ? 'Create the first administrator account to secure this app.'
                            : 'Sign in to continue to your inventory.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _username,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => (value?.trim().length ?? 0) < 3
                            ? 'Enter at least 3 characters.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        textInputAction:
                            setup ? TextInputAction.next : TextInputAction.done,
                        onFieldSubmitted: (_) => setup ? null : _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                          ),
                        ),
                        validator: (value) => (value?.length ?? 0) < 8
                            ? 'Password must be at least 8 characters.'
                            : null,
                      ),
                      if (setup) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmPassword,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            labelText: 'Confirm password',
                            prefixIcon: Icon(Icons.lock_reset_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value != _password.text
                              ? 'Passwords do not match.'
                              : null,
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: _busy ? null : _submit,
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(setup
                                ? Icons.admin_panel_settings
                                : Icons.login),
                        label: Text(_busy
                            ? 'Please wait…'
                            : setup
                                ? 'Create administrator'
                                : 'Sign in'),
                        style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final authDao = ref.read(authDaoProvider);
      final user = widget.isInitialSetup
          ? await authDao.createInitialAdmin(
              username: _username.text,
              password: _password.text,
            )
          : await authDao.authenticate(_username.text, _password.text);
      if (user == null) {
        setState(() => _error = 'Incorrect username or password.');
        return;
      }
      widget.onAuthenticated(user);
    } catch (error) {
      setState(() {
        _error = widget.isInitialSetup
            ? 'Could not create the administrator. Check that the username is unique.'
            : 'Could not sign in. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
