import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/main.dart';

void main() {
  testWidgets('Welcome flow shows wordmark and primary CTA', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GolfBitsApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Bits Dots Junk'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.textContaining('Tally up'), findsOneWidget);
  });
}
