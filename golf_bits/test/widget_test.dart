import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/main.dart';

void main() {
  testWidgets('Home screen shows title and gallery entry', (WidgetTester tester) async {
    await tester.pumpWidget(const GolfBitsApp());
    expect(find.text('Golf Bits'), findsOneWidget);
    expect(find.textContaining('Material 3'), findsOneWidget);
    expect(find.text('Style guide & components'), findsOneWidget);
  });
}
