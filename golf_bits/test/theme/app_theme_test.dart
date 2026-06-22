import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/theme/app_colors.dart';
import 'package:golf_bits/theme/app_theme.dart';
import 'package:golf_bits/theme/theme_controller.dart';

void main() {
  testWidgets('AppTheme bits colour differs between light and dark themes', (tester) async {
    Color? lightBits;
    Color? darkBits;

    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            Theme(
              data: AppTheme.light(),
              child: Builder(
                builder: (context) {
                  lightBits = AppTheme.bits(context);
                  return const SizedBox();
                },
              ),
            ),
            Theme(
              data: AppTheme.dark(),
              child: Builder(
                builder: (context) {
                  darkBits = AppTheme.bits(context);
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(lightBits, AppColors.bitsPositiveLight);
    expect(darkBits, AppColors.fairway);
    expect(lightBits, isNot(equals(darkBits)));
  });

  testWidgets('ThemeController exposes mode to descendants', (tester) async {
    await tester.pumpWidget(
      ThemeController(
        mode: ThemeMode.light,
        setMode: (_) {},
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              final controller = ThemeController.maybeOf(context);
              return Scaffold(body: Text(controller?.mode.name ?? 'missing'));
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('light'), findsOneWidget);
  });
}
