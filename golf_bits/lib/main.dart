import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_root.dart';
import 'config/supabase_env.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseEnv.isConfigured) {
    await Supabase.initialize(
      url: SupabaseEnv.url,
      anonKey: SupabaseEnv.anonKey,
      authOptions: const FlutterAuthClientOptions(
        detectSessionInUri: true,
      ),
    );
  }

  runApp(const GolfBitsApp());
}

/// Root app: Material 3, dark-first, Lexend + brand ColorScheme.
class GolfBitsApp extends StatelessWidget {
  const GolfBitsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Golf Bits',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const AuthRoot(),
    );
  }
}
