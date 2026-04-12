import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/main.dart';

void main() {
  testWidgets('Welcome flow shows wordmark and primary CTA', (WidgetTester tester) async {
    await tester.pumpWidget(const GolfBitsApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('GOLF BITS'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.textContaining('Track the bits'), findsOneWidget);
  });
}
