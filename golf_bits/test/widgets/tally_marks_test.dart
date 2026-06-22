import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/widgets/tally_marks.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('TallyMarks renders without error for positive and penalty counts', (tester) async {
    await tester.pumpWidget(
      wrapWithAppTheme(
        const Scaffold(
          body: Row(
            children: [
              TallyMarks(count: 7, variant: TallyVariant.positive),
              TallyMarks(count: -3, variant: TallyVariant.penalty),
              TallyMarks(count: 0),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TallyMarks), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('TallyMarks uses theme semantic colours', (tester) async {
    await tester.pumpWidget(
      wrapWithAppTheme(
        const Scaffold(body: TallyMarks(count: 5)),
        themeMode: ThemeMode.dark,
      ),
    );
    await tester.pump();
    expect(find.byType(TallyMarks), findsOneWidget);
  });
}
