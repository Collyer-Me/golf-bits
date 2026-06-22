import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/screens/welcome_screen.dart';
import 'package:golf_bits/theme/app_theme.dart';

void main() {
  Future<void> pumpWelcome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: WelcomeScreen(),
      ),
    );
    await tester.pump();
  }

  testWidgets('Welcome screen shows brand row, carousel, and guest CTA', (tester) async {
    await pumpWelcome(tester);

    expect(find.text('Bits Dots Junk'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Continue as guest'), findsOneWidget);
    expect(find.textContaining('birdies'), findsOneWidget);
    expect(find.text('Tally up.\nSettle up.'), findsOneWidget);
  });

  testWidgets('Welcome carousel advances when swiped', (tester) async {
    await pumpWelcome(tester);

    expect(find.textContaining('birdies'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Award bits\nfor anything.'), findsOneWidget);
  });

  testWidgets('Welcome page indicator jumps to slide', (tester) async {
    await pumpWelcome(tester);

    await tester.tap(find.bySemanticsLabel('Slide 3 of 3'));
    await tester.pumpAndSettle();

    expect(find.text('See who\nowes who.'), findsOneWidget);
  });

  testWidgets('Welcome screen always uses dark on-course theme', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const WelcomeScreen(),
      ),
    );
    await tester.pump();

    final ctaContext = tester.element(find.text('Get started'));
    expect(Theme.of(ctaContext).brightness, Brightness.dark);
    expect(Theme.of(ctaContext).colorScheme.primary, AppTheme.dark().colorScheme.primary);
  });
}
