import 'package:flutter/material.dart';

import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const WelcomeScreen(),
    );
  }
}
