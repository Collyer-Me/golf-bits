import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/theme/theme_preferences.dart';

void main() {
  group('ThemePreferences', () {
    test('defaults to dark when no user choice is stored', () async {
      final mode = await ThemePreferences.loadInitialMode();
      expect(mode, ThemeMode.dark);
    });
  });
}
