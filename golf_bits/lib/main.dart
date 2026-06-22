import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_root.dart';
import 'auth/pending_auth_link.dart';
import 'config/supabase_env.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

final RouteObserver<ModalRoute<void>> appRouteObserver = RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseEnv.isConfigured) {
    // Email links (recovery, signup confirm) carry `type` in the URL; Supabase may
    // strip it during initialize — snapshot first so AuthRoot can route correctly.
    PendingAuthLink.captureFromUriBeforeSupabaseInit(Uri.base);
    await Supabase.initialize(
      url: SupabaseEnv.url,
      publishableKey: SupabaseEnv.anonKey,
      authOptions: const FlutterAuthClientOptions(
        detectSessionInUri: true,
      ),
    );
  }

  runApp(const GolfBitsApp());
}

/// Root app: Material 3, Bits Dots Junk brand, dark ("on course") + light
/// ("in the clubhouse") themes with a system-default [ThemeMode] toggle.
class GolfBitsApp extends StatefulWidget {
  const GolfBitsApp({super.key});

  @override
  State<GolfBitsApp> createState() => _GolfBitsAppState();
}

class _GolfBitsAppState extends State<GolfBitsApp> {
  static const _themePrefKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = switch (prefs.getString(_themePrefKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      if (mounted && mode != _themeMode) setState(() => _themeMode = mode);
    } catch (_) {
      // Preferences unavailable (e.g. first run / tests) — keep system default.
    }
  }

  void _setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    setState(() => _themeMode = mode);
    _persistThemeMode(mode);
  }

  Future<void> _persistThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefKey, mode.name);
    } catch (_) {
      // Best-effort; a failed save just means the choice isn't remembered.
    }
  }

  @override
  Widget build(BuildContext context) {
    return ThemeController(
      mode: _themeMode,
      setMode: _setThemeMode,
      child: MaterialApp(
        title: 'Bits Dots Junk',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: _themeMode,
        navigatorObservers: [appRouteObserver],
        home: const AuthRoot(),
      ),
    );
  }
}
