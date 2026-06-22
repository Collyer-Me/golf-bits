import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/screens/welcome_screen.dart';
import 'package:golf_bits/theme/app_theme.dart';

void main() {
  testWidgets('Welcome screen shows wordmark, carousel, and guest CTA', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const WelcomeScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('Bits Dots Junk'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Continue as guest'), findsOneWidget);
    expect(find.textContaining('birdies'), findsOneWidget);
  });

  testWidgets('Welcome carousel advances when swiped', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const WelcomeScreen(),
      ),
    );
    await tester.pump();

    expect(find.textContaining('birdies'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.textContaining('your crew'), findsOneWidget);
  });
}
