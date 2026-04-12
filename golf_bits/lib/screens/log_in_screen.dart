import 'package:flutter/material.dart';

import '../navigation/auth_navigation.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_wordmark.dart';
import 'guest_play_sheet.dart';
import 'sign_up_screen.dart';

/// Log in — mirrors sign-up structure; guest sheet + home on success stub.
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

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // TODO: supabase.auth.signInWithPassword
    openAppHome(context);
  }

  void _openGuestSheet() {
    GuestPlaySheet.show(
      context,
      onContinueGuest: () {
        Navigator.of(context).pop();
        openAppHome(context);
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
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password reset coming soon')),
                      );
                    },
                    child: const Text('Forgot password?'),
                  ),
                ),
                SizedBox(height: AppTheme.space2),
                Row(
                  children: [
                    Expanded(child: Divider(color: scheme.outlineVariant)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3),
                      child: Text(
                        'OR CONTINUE WITH',
                        style: text.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: scheme.outlineVariant)),
                  ],
                ),
                SizedBox(height: AppTheme.space4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Apple sign-in coming soon')),
                          );
                        },
                        icon: const Icon(Icons.apple, size: 22),
                        label: const Text('Apple'),
                      ),
                    ),
                    SizedBox(width: AppTheme.space3),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Google sign-in coming soon')),
                          );
                        },
                        icon: Icon(Icons.g_mobiledata, size: 28, color: scheme.onSurface),
                        label: const Text('Google'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.space3),
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
                  onPressed: _submit,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Log In'),
                      SizedBox(width: AppTheme.space2),
                      Icon(Icons.arrow_forward, size: 20),
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
