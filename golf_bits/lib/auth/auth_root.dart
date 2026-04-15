import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import 'pending_auth_link.dart';
import 'profile_bootstrap.dart';
import '../screens/home_screen.dart';
import '../screens/log_in_screen.dart';
import '../screens/update_password_screen.dart';
import '../screens/welcome_screen.dart';

/// Root auth + routing: restores session from storage, toggles Welcome vs Home, handles recovery links.
class AuthRoot extends StatefulWidget {
  const AuthRoot({super.key});

  static AuthRootState? maybeOf(BuildContext context) => context.findAncestorStateOfType<AuthRootState>();

  @override
  State<AuthRoot> createState() => AuthRootState();
}

class AuthRootState extends State<AuthRoot> {
  bool _ready = false;
  bool _inApp = false;
  StreamSubscription<AuthState>? _authSub;
  bool _recoveryRouteOpen = false;

  /// Enter the main shell (after login, guest, or location onboarding). Pops auth modals first.
  void enterApp() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    setState(() => _inApp = true);
  }

  /// Leave the main shell (after sign-out or when not using Supabase guest exit).
  void exitApp() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    setState(() => _inApp = false);
  }

  @override
  void initState() {
    super.initState();
    if (SupabaseEnv.isConfigured) {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(_onAuthState);
    }
    unawaited(_hydrate());
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _hydrate() async {
    if (!SupabaseEnv.isConfigured) {
      if (mounted) setState(() => _ready = true);
      return;
    }
    // currentSession is hydrated from storage by supabase_flutter on startup.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    final pendingRecovery = PendingAuthLink.takePasswordRecovery();
    final pendingEmailSignup = PendingAuthLink.takeEmailSignupConfirmed();

    setState(() {
      _ready = true;
      _inApp = Supabase.instance.client.auth.currentSession != null;
    });

    if (pendingRecovery || _isRecoveryLink()) {
      _openRecoveryScreen();
    }

    if (pendingEmailSignup) {
      _showEmailConfirmedDialog();
    }
  }

  void _onAuthState(AuthState data) {
    if (!mounted) return;
    if (data.event == AuthChangeEvent.passwordRecovery || _isRecoveryLink()) {
      _openRecoveryScreen();
      return;
    }
    if (data.event == AuthChangeEvent.signedOut && _inApp) {
      exitApp();
      return;
    }

    final hasSession = Supabase.instance.client.auth.currentSession != null;
    if (hasSession && !_inApp) {
      unawaited(ProfileBootstrap.ensureCurrentUserProfile());
      enterApp();
    }
  }

  bool _isRecoveryLink() {
    if (!kIsWeb) return false;
    final uri = Uri.base;
    if (uri.queryParameters['type'] == 'recovery') return true;
    return uri.fragment.contains('type=recovery');
  }

  void _openRecoveryScreen() {
    if (_recoveryRouteOpen || !mounted) return;
    _recoveryRouteOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const UpdatePasswordScreen(),
        ),
      );
      _recoveryRouteOpen = false;
    });
  }

  void _showEmailConfirmedDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hasSession = Supabase.instance.client.auth.currentSession != null;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Email confirmed'),
            content: Text(
              hasSession
                  ? 'Your email is verified and you are signed in.'
                  : 'Your email is verified. Sign in with your password to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (!hasSession) {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(builder: (_) => const LogInScreen()),
                    );
                  }
                },
                child: Text(hasSession ? 'Continue' : 'Log in'),
              ),
            ],
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!SupabaseEnv.isConfigured) {
      return _inApp ? const HomeScreen() : const WelcomeScreen();
    }
    return _inApp ? const HomeScreen() : const WelcomeScreen();
  }
}
