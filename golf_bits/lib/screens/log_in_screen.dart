import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_error_message.dart';
import '../auth/profile_bootstrap.dart';
import '../auth/auth_redirect.dart';
import '../config/supabase_env.dart';
import '../navigation/auth_navigation.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_wordmark.dart';
import 'guest_play_sheet.dart';
import 'sign_up_screen.dart';

/// Log in — email/password, password reset, and guest (anonymous when enabled in the Supabase project).
class LogInScreen extends StatefulWidget {
  const LogInScreen({super.key});

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!SupabaseEnv.isConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Supabase is not configured. For GitHub Pages, add repository secrets '
            'SUPABASE_URL and SUPABASE_ANON_KEY, then redeploy.',
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      await ProfileBootstrap.ensureCurrentUserProfile();
      if (mounted) openAppHome(context);
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

  Future<void> _sendPasswordReset() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email address above first.')),
      );
      return;
    }
    if (!SupabaseEnv.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supabase is not configured.')),
      );
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: supabaseAuthRedirectUrl(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check your email for a password reset link.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    }
  }

  void _openGuestSheet() {
    GuestPlaySheet.show(
      context,
      onContinueGuest: () async {
        Navigator.of(context).pop();
        if (SupabaseEnv.isConfigured) {
          try {
            await Supabase.instance.client.auth.signInAnonymously();
          } on AuthException {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Anonymous sign-in is disabled in the project. You can still play on this device.',
                  ),
                ),
              );
            }
          }
        }
        if (mounted) openAppHome(context);
      },
      onCreateAccountInstead: () {
        Navigator.of(context).pop();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Welcome back'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppTheme.screenPadding.copyWith(bottom: AppTheme.space6),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: AppTheme.space2),
                const BrandWordmark(size: BrandWordmarkSize.screen),
                SizedBox(height: AppTheme.space1),
                Text(
                  'THE MODERN CADDY',
                  textAlign: TextAlign.center,
                  style: text.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: AppTheme.letterTagline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppTheme.space7),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: _field(
                    hint: 'Email address',
                    icon: Icons.mail_outline,
                  ),
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
                    hint: 'Password',
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter your password' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _sendPasswordReset,
                    child: const Text('Forgot password?'),
                  ),
                ),
                SizedBox(height: AppTheme.space6),
                Center(
                  child: TextButton(
                    onPressed: _openGuestSheet,
                    child: const Text('Continue as guest'),
                  ),
                ),
                SizedBox(height: AppTheme.space2),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text("Don't have an account? ", style: text.bodyMedium),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => const SignUpScreen(),
                          ),
                        );
                      },
                      child: const Text('Sign up'),
                    ),
                  ],
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
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Log In'),
                            SizedBox(width: AppTheme.space2),
                            Icon(Icons.arrow_forward, size: AppTheme.iconArrow),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
