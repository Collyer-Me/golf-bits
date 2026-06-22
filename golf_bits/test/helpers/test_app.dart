import 'package:flutter/material.dart';
import 'package:golf_bits/theme/app_theme.dart';

/// Wraps [child] in a [MaterialApp] with the production light/dark themes.
Widget wrapWithAppTheme(Widget child, {ThemeMode themeMode = ThemeMode.light}) {
  return MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: themeMode,
    home: child,
  );
}
