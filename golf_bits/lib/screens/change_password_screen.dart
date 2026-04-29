import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_error_message.dart';
import '../theme/app_theme.dart';

/// Change password while signed in: verifies current password via [signInWithPassword], then [updateUser].
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email;
    if (email == null || email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account has no email on file. Use the forgot-password flow from log in.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: _current.text,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      final lower = e.message.toLowerCase();
      final wrongPassword = lower.contains('invalid') &&
          (lower.contains('login') || lower.contains('credential') || lower.contains('password'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wrongPassword ? 'Current password is incorrect.' : authErrorMessage(e),
          ),
        ),
      );
      if (mounted) setState(() => _loading = false);
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _password.text),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed')),
      );
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppTheme.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter your current password, then choose a new one.',
                  style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                ),
                SizedBox(height: AppTheme.space6),
                TextFormField(
                  controller: _current,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'Current password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your current password' : null,
                ),
                SizedBox(height: AppTheme.buttonPadV),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'New password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a password';
                    if (v.length < 6) return 'At least 6 characters';
                    return null;
                  },
                ),
                SizedBox(height: AppTheme.buttonPadV),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: _loading ? null : (_) => unawaited(_submit()),
                  decoration: const InputDecoration(
                    hintText: 'Confirm new password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) {
                    if (v != _password.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                SizedBox(height: AppTheme.space8),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? SizedBox(
                          height: AppTheme.iconInline,
                          width: AppTheme.iconInline,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : const Text('Update password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
