import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_error_message.dart';
import '../auth/auth_redirect.dart';
import '../auth/profile_bootstrap.dart';
import '../config/supabase_env.dart';
import '../theme/app_theme.dart';
import 'location_permission_screen.dart';
import 'log_in_screen.dart';

/// Create account — email/password via Supabase.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
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
      final response = await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text.trim(),
        data: {'full_name': _name.text.trim()},
        emailRedirectTo: supabaseAuthRedirectUrl(),
      );
      if (!mounted) return;
      if (response.session != null) {
        await ProfileBootstrap.ensureCurrentUserProfile();
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const LocationPermissionScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check your email to confirm your account, then sign in.'),
          ),
        );
      }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Create Account'),
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
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.secondary.withValues(alpha: AppTheme.opacitySecondaryFill),
                      borderRadius: BorderRadius.circular(AppTheme.stadiumRadius),
                      border: Border.all(
                        color: scheme.secondary.withValues(alpha: AppTheme.opacitySecondaryBorder),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space4,
                        vertical: AppTheme.space2,
                      ),
                      child: Text(
                        'WELCOME TO THE CLUBHOUSE',
                        style: text.labelSmall?.copyWith(
                          color: scheme.secondary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: AppTheme.letterBadge,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: AppTheme.space7),
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: _field(
                    hint: 'Your name',
                    icon: Icons.person_outline,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                ),
                SizedBox(height: AppTheme.buttonPadV),
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
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a password';
                    if (v.length < 6) return 'At least 6 characters';
                    return null;
                  },
                ),
                SizedBox(height: AppTheme.space6),
                Text(
                  'By continuing you agree to our Terms and acknowledge the Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                SizedBox(height: AppTheme.space4),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Already have an account? ', style: text.bodyMedium),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => const LogInScreen(),
                          ),
                        );
                      },
                      child: const Text('Log in'),
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
                            Text('Create Account'),
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
