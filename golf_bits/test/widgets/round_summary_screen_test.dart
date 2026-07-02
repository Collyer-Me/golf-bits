import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/models/round_result.dart';
import 'package:golf_bits/screens/round_summary_screen.dart';
import 'package:golf_bits/widgets/brand_app_bar.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('demo round summary shows ledger and settle up', (tester) async {
    await tester.pumpWidget(
      wrapWithAppTheme(const RoundSummaryScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BrandAppBar), findsOneWidget);
    expect(find.text('Round complete'), findsOneWidget);
    expect(find.text('THE LEDGER'), findsOneWidget);
    expect(find.text('SETTLE UP'), findsOneWidget);
    expect(find.text('Alex'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Taylor'), 120);
    expect(find.text('Taylor'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Back to Home'), 120);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Back to Home'), findsOneWidget);
  });

  testWidgets('custom result shows in-progress headline', (tester) async {
    final demo = RoundResult.previewDemo();
    final result = RoundResult(
      courseName: demo.courseName,
      courseShortTitle: demo.courseShortTitle,
      holeCount: demo.holeCount,
      players: demo.players,
      winnerName: demo.winnerName,
      winnerBits: demo.winnerBits,
      completed: false,
      standings: demo.standings,
      leftEarly: demo.leftEarly,
    );
    await tester.pumpWidget(
      wrapWithAppTheme(RoundSummaryScreen(result: result)),
    );
    await tester.pump();

    expect(find.text('Round in progress'), findsOneWidget);
    expect(find.text('Round complete'), findsNothing);
  });
}
