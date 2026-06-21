import 'package:flutter/material.dart';

import '../widgets/brand_app_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_error_message.dart';
import '../auth/auth_redirect.dart';
import '../auth/guest_user.dart';
import '../auth/guest_promotion.dart';
import '../auth/profile_bootstrap.dart';
import '../config/supabase_env.dart';
import '../navigation/auth_navigation.dart';
import '../theme/app_theme.dart';
import 'location_permission_screen.dart';
import 'log_in_screen.dart';

/// Links email + password to the **current** anonymous session (keeps `auth.uid()` and rounds).
class GuestUpgradeScreen extends StatefulWidget {
  const GuestUpgradeScreen({super.key});

  @override
  State<GuestUpgradeScreen> createState() => _GuestUpgradeScreenState();
}

class _GuestUpgradeScreenState extends State<GuestUpgradeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  InputDecoration _field({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
    );
  }

  Future<void> _showVerifyEmailDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm your email'),
        content: const Text(
          'Check your email for a confirmation link if required by your project settings. '
          'After confirming, your guest rounds stay on this account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!SupabaseEnv.isConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supabase is not configured.')),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || !isSupabaseGuestUser(user)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upgrade is only available while playing as a guest.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          email: _email.text.trim(),
          password: _password.text.trim(),
          data: {'full_name': _name.text.trim()},
        ),
        emailRedirectTo: supabaseAuthRedirectUrl(),
      );
      if (!mounted) return;

      await ProfileBootstrap.ensureCurrentUserProfile();

      final next = Supabase.instance.client.auth.currentUser;
      final stillGuest = next != null && isSupabaseGuestUser(next);
      final session = Supabase.instance.client.auth.currentSession;

      // Same auth user id → rounds under RLS stay visible once email/password stuck.
      if (!stillGuest && session != null) {
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const LocationPermissionScreen()),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account upgraded. Your rounds stayed with you.')),
        );
        Navigator.of(context).pop();
        return;
      }

      await _showVerifyEmailDialog();
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

    final user = SupabaseEnv.isConfigured ? Supabase.instance.client.auth.currentUser : null;
    final validGuest = user != null && isSupabaseGuestUser(user);

    return Scaffold(
      appBar: const BrandAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppTheme.screenPadding.copyWith(bottom: AppTheme.space6),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!validGuest) ...[
                  Text(
                    'You are not on a guest session. Use Get Started to create an account, or log in.',
                    style: text.bodyMedium?.copyWith(color: scheme.error),
                  ),
                  SizedBox(height: AppTheme.space6),
                  FilledButton(
                    onPressed: () {
                      signOutAndReturnToWelcome(context);
                    },
                    child: const Text('Back to welcome'),
                  ),
                ] else ...[
                  Text(GuestPromotionCopy.subtitle, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  SizedBox(height: AppTheme.space6),
                  TextFormField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: _field(hint: 'Your name', icon: Icons.person_outline),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                  ),
                  SizedBox(height: AppTheme.buttonPadV),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: _field(hint: 'Email address', icon: Icons.mail_outline),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter your email';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  SizedBox(height: AppTheme.buttonPadV),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: _field(
                      hint: 'Choose a password',
                      icon: Icons.lock_outline,
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
                  SizedBox(height: AppTheme.space5),
                  Text(
                    'You must enable anonymous identity linking in Supabase Auth if this step fails or hangs.',
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  SizedBox(height: AppTheme.space6),
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
                        : Text(GuestPromotionCopy.upgradeCta),
                  ),
                  SizedBox(height: AppTheme.space3),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(builder: (_) => const LogInScreen()),
                      );
                    },
                    child: const Text('I already have an account — log in'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
