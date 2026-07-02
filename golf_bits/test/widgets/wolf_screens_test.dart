import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/models/round_game_config.dart';
import 'package:golf_bits/models/wolf_scoring.dart';
import 'package:golf_bits/screens/round_standings_screen.dart';
import 'package:golf_bits/screens/wolf_call_screen.dart';
import 'package:golf_bits/screens/wolf_score_hole_screen.dart';
import 'package:golf_bits/widgets/brand_app_bar.dart';

import '../helpers/test_app.dart';
import '../helpers/wolf_test_fixtures.dart';

void main() {
  group('WolfCallScreen', () {
    testWidgets('shows wolf banner and call actions on hole 1', (tester) async {
      final state = testWolfRoundState();
      await tester.pumpWidget(wrapWithAppTheme(WolfCallScreen(state: state)));
      await tester.pumpAndSettle();

      expect(find.byType(BrandAppBar), findsOneWidget);
      expect(find.text("You're the Wolf"), findsOneWidget);
      expect(find.text('Declare Blind Wolf'), findsOneWidget);
      expect(find.text('Score the hole'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Go Lone Wolf'), 120);
      expect(find.text('Go Lone Wolf'), findsOneWidget);
    });

    testWidgets('prompts when continuing without a call', (tester) async {
      await tester.pumpWidget(
        wrapWithAppTheme(WolfCallScreen(state: testWolfRoundState())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Score the hole'));
      await tester.pumpAndSettle();

      expect(find.text('Choose Blind Wolf, a partner, or Lone Wolf'), findsOneWidget);
      expect(find.byType(WolfScoreHoleScreen), findsNothing);
    });

    testWidgets('all opponents selectable as partner on hole 1', (tester) async {
      await tester.pumpWidget(
        wrapWithAppTheme(WolfCallScreen(state: testWolfRoundState())),
      );
      await tester.pumpAndSettle();

      expect(find.text('WAITING'), findsNothing);
      await tester.scrollUntilVisible(find.text('Jordan'), 120);
      expect(find.text('Partner'), findsNWidgets(3));
      await tester.scrollUntilVisible(find.text('Go Lone Wolf'), 120);
      await tester.tap(find.text('Go Lone Wolf'));
      await tester.pump();
      await tester.tap(find.text('Score the hole'));
      await tester.pumpAndSettle();
      expect(find.byType(WolfScoreHoleScreen), findsOneWidget);
    });

    testWidgets('first opponent partner button selects partner on hole 1', (tester) async {
      await tester.pumpWidget(
        wrapWithAppTheme(WolfCallScreen(state: testWolfRoundState())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Partner'), findsWidgets);
      await tester.tap(find.text('Partner').first);
      await tester.pump();

      await tester.tap(find.text('Score the hole'));
      await tester.pumpAndSettle();

      expect(find.byType(WolfScoreHoleScreen), findsOneWidget);
    });

    testWidgets('blind wolf navigates to score screen', (tester) async {
      await tester.pumpWidget(
        wrapWithAppTheme(WolfCallScreen(state: testWolfRoundState())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Declare Blind Wolf'));
      await tester.pump();
      await tester.tap(find.text('Score the hole'));
      await tester.pumpAndSettle();

      expect(find.byType(WolfScoreHoleScreen), findsOneWidget);
      expect(find.text('Score the hole'), findsWidgets);
      expect(find.text('TEAMS · STROKES & BITS'), findsOneWidget);
    });

    testWidgets('standings action opens standings screen', (tester) async {
      await tester.pumpWidget(
        wrapWithAppTheme(WolfCallScreen(state: testWolfRoundState())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Standings'));
      await tester.pumpAndSettle();

      expect(find.byType(RoundStandingsScreen), findsOneWidget);
      expect(find.text('WOLF POINTS · THE MATCH'), findsOneWidget);
    });
  });

  group('RoundStandingsScreen', () {
    testWidgets('wolf-only lists players sorted by wolf points', (tester) async {
      final state = testWolfRoundState(
        wolfHoleResults: {
          1: WolfHoleResult(
            hole: 1,
            wolfKey: 'you',
            call: const WolfCall(type: WolfCallType.partner, partnerKey: 'sam'),
            grossByPlayer: const {'you': 4, 'sam': 4, 'alex': 5, 'jordan': 5},
            pointsByPlayer: const {'you': 2, 'sam': 2, 'alex': -2, 'jordan': -2},
          ),
        },
      );

      await tester.pumpWidget(wrapWithAppTheme(RoundStandingsScreen(state: state)));
      await tester.pumpAndSettle();

      expect(find.text('Standings'), findsOneWidget);
      expect(find.text('WOLF POINTS · THE MATCH'), findsOneWidget);
      expect(find.text('You'), findsWidgets);
      expect(find.text('Sam'), findsWidgets);
      expect(find.text('★ LEADING'), findsOneWidget);
      expect(find.byType(SegmentedButton<bool>), findsNothing);
    });

    testWidgets('dual format toggles between wolf and bits ledgers', (tester) async {
      final state = testWolfRoundState(
        formats: const [RoundFormat.wolf, RoundFormat.bits],
        wolfHoleResults: {
          1: WolfHoleResult(
            hole: 1,
            wolfKey: 'you',
            call: const WolfCall(type: WolfCallType.lone),
            grossByPlayer: const {'you': 3, 'sam': 5, 'alex': 5, 'jordan': 5},
            pointsByPlayer: const {'you': 6, 'sam': -2, 'alex': -2, 'jordan': -2},
          ),
        },
        bitsByPlayer: const {'you': 1, 'sam': 4, 'alex': 0, 'jordan': -1},
      );

      await tester.pumpWidget(wrapWithAppTheme(RoundStandingsScreen(state: state)));
      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<bool>), findsOneWidget);
      expect(find.text('WOLF POINTS · THE MATCH'), findsOneWidget);

      await tester.tap(find.text('Bits'));
      await tester.pumpAndSettle();

      expect(find.text('BITS LEDGER · SIDE GAME'), findsOneWidget);
      expect(find.text('Sam'), findsWidgets);
    });
  });
}
