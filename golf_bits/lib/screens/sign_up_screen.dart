import 'package:flutter/material.dart';

import '../widgets/brand_app_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_error_message.dart';
import '../auth/guest_user.dart';
import '../auth/guest_promotion.dart';
import '../auth/pending_auth_link.dart';
import '../auth/auth_redirect.dart';
import '../auth/profile_bootstrap.dart';
import '../config/supabase_env.dart';
import '../theme/app_theme.dart';
import 'guest_upgrade_screen.dart';
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
  late bool _guestSessionSignup;
  bool _riskSeparateSignup = false;

  @override
  void initState() {
    super.initState();
    final inviteEmail = PendingAuthLink.inviteEmail;
    if (inviteEmail != null && inviteEmail.trim().isNotEmpty) {
      _email.text = inviteEmail.trim();
    }
    _guestSessionSignup = SupabaseEnv.isConfigured &&
        isSupabaseGuestUser(Supabase.instance.client.auth.currentUser);
  }

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

  Future<void> _showCheckEmailDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm your email'),
        content: const Text(
          'Your account was created. Check your email for the confirmation link, then log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(builder: (_) => const LogInScreen()),
              );
            },
            child: const Text('Go to Log in'),
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
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const LocationPermissionScreen()),
        );
      } else {
        await _showCheckEmailDialog();
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
      appBar: const BrandAppBar(),
      body: SafeArea(
        child: _guestSessionSignup && !_riskSeparateSignup
            ? Padding(
                padding: AppTheme.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: AppTheme.space2),
                    Text(
                      GuestPromotionCopy.subtitle,
                      style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    SizedBox(height: AppTheme.space6),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(builder: (_) => const GuestUpgradeScreen()),
                        );
                      },
                      child: Text(GuestPromotionCopy.upgradeCta),
                    ),
                    SizedBox(height: AppTheme.space3),
                    TextButton(
                      onPressed: () => setState(() => _riskSeparateSignup = true),
                      child: Text(GuestPromotionCopy.createInsteadCta),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: AppTheme.screenPadding.copyWith(bottom: AppTheme.space6),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_guestSessionSignup && _riskSeparateSignup) ...[
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.errorContainer.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.space3),
                            child: Text(
                              'Separate signup logs you into a new account. Existing guest rounds will not carry over.',
                              style: text.bodySmall?.copyWith(color: scheme.onErrorContainer),
                            ),
                          ),
                        ),
                        SizedBox(height: AppTheme.space5),
                      ],
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
                if (PendingAuthLink.inviteEmail != null) ...[
                  Text(
                    'Invite detected: create your account with this email to link your round participation.',
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  SizedBox(height: AppTheme.space3),
                ],
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
