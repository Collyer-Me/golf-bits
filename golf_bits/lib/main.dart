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
/// ("in the clubhouse") themes. Defaults to dark; light only when chosen in Profile.
class GolfBitsApp extends StatefulWidget {
  const GolfBitsApp({super.key});

  @override
  State<GolfBitsApp> createState() => _GolfBitsAppState();
}

class _GolfBitsAppState extends State<GolfBitsApp> {
  static const _themePrefKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_themePrefKey);
      final mode = stored == 'light' ? ThemeMode.light : ThemeMode.dark;
      if (stored == 'system') {
        await prefs.setString(_themePrefKey, 'dark');
      }
      if (mounted && mode != _themeMode) setState(() => _themeMode = mode);
    } catch (_) {
      // Preferences unavailable (e.g. first run / tests) — keep dark default.
    }
  }

  void _setThemeMode(ThemeMode mode) {
    final resolved = mode == ThemeMode.light ? ThemeMode.light : ThemeMode.dark;
    if (resolved == _themeMode) return;
    setState(() => _themeMode = resolved);
    _persistThemeMode(resolved);
  }

  Future<void> _persistThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _themePrefKey,
        mode == ThemeMode.light ? 'light' : 'dark',
      );
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
