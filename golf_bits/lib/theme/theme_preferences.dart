import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence for light/dark choice. Dark is the default; light applies
/// only after the user explicitly toggles Appearance in Profile.
class ThemePreferences {
  ThemePreferences._();

  static const themeModeKey = 'theme_mode';
  static const themeUserSetKey = 'theme_user_set';

  /// Loads the initial [ThemeMode] before [runApp]. Clears orphan `light`
  /// values that were never set via Profile.
  static Future<ThemeMode> loadInitialMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(themeModeKey);
      if (stored == 'system') {
        await prefs.setString(themeModeKey, 'dark');
      }
      final userSet = prefs.getBool(themeUserSetKey) ?? false;
      if (userSet && stored == 'light') {
        return ThemeMode.light;
      }
      if (stored == 'light' && !userSet) {
        await prefs.setString(themeModeKey, 'dark');
      }
      return ThemeMode.dark;
    } catch (_) {
      return ThemeMode.dark;
    }
  }

  static Future<void> persistUserChoice(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(themeUserSetKey, true);
      await prefs.setString(
        themeModeKey,
        mode == ThemeMode.light ? 'light' : 'dark',
      );
    } catch (_) {
      // Best-effort.
    }
  }
}
