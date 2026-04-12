import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GolfBitsApp());
}

/// Root app: Material 3, dark-first.
class GolfBitsApp extends StatelessWidget {
  const GolfBitsApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2E7D32);

    return MaterialApp(
      title: 'Golf Bits',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          backgroundColor: ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.dark,
          ).surfaceContainerHigh,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
