import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import 'profile_bootstrap.dart';
import '../screens/home_screen.dart';
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
    setState(() {
      _ready = true;
      _inApp = Supabase.instance.client.auth.currentSession != null;
    });
  }

  void _onAuthState(AuthState data) {
    if (!mounted) return;
    if (data.event == AuthChangeEvent.passwordRecovery) {
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
