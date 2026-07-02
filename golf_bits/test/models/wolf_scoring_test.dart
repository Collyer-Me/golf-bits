import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/models/wolf_scoring.dart';

void main() {
  group('resolveWolfPlayerId', () {
    const teeOrder = ['you', 'sam', 'alex', 'jordan'];

    test('rotates by hole index for normal holes', () {
      expect(
        resolveWolfPlayerId(
          holeIndex: 0,
          holeCount: 18,
          teeOrder: teeOrder,
          wolfPointsBeforeHole: const {},
        ),
        'you',
      );
      expect(
        resolveWolfPlayerId(
          holeIndex: 4,
          holeCount: 18,
          teeOrder: teeOrder,
          wolfPointsBeforeHole: const {},
        ),
        'you',
      );
      expect(
        resolveWolfPlayerId(
          holeIndex: 1,
          holeCount: 18,
          teeOrder: teeOrder,
          wolfPointsBeforeHole: const {},
        ),
        'sam',
      );
    });

    test('9th hole played uses trailing player on 9-hole round', () {
      expect(
        resolveWolfPlayerId(
          holeIndex: 8,
          holeCount: 9,
          teeOrder: teeOrder,
          wolfPointsBeforeHole: const {
            'you': 6,
            'sam': 5,
            'alex': 4,
            'jordan': 3,
          },
        ),
        'jordan',
      );
    });

    test('holes 17-18 use trailing player on 18-hole round', () {
      const points = {
        'you': 6,
        'sam': 5,
        'alex': 4,
        'jordan': 3,
      };
      expect(
        resolveWolfPlayerId(
          holeIndex: 16,
          holeCount: 18,
          teeOrder: teeOrder,
          wolfPointsBeforeHole: points,
        ),
        'jordan',
      );
      expect(
        resolveWolfPlayerId(
          holeIndex: 17,
          holeCount: 18,
          teeOrder: teeOrder,
          wolfPointsBeforeHole: points,
        ),
        'jordan',
      );
    });
  });

  group('settleWolfHole — handoff worked example', () {
    test('partner win net best ball', () {
      const teeOrder = ['you', 'sam', 'alex', 'jordan'];
      const handicaps = {'you': 12, 'sam': 8, 'alex': 16, 'jordan': 4};
      const gross = {'you': 4, 'sam': 4, 'alex': 5, 'jordan': 5};
      const call = WolfCall(type: WolfCallType.partner, partnerKey: 'sam');

      final result = settleWolfHole(
        teeOrder: teeOrder,
        wolfKey: 'you',
        call: call,
        grossByPlayer: gross,
        basis: WolfScoringBasis.net,
        handicaps: handicaps,
        strokeIndex: 5,
      );

      expect(result.wolfBestBall, 3);
      expect(result.fieldBestBall, 4);
      expect(result.winner, WolfHoleWinner.wolfSide);
      expect(result.pointsByPlayer['you'], 2);
      expect(result.pointsByPlayer['sam'], 2);
      expect(result.pointsByPlayer['alex'], -2);
      expect(result.pointsByPlayer['jordan'], -2);
      expect(result.pointsByPlayer.values.fold(0, (a, b) => a + b), 0);
    });
  });

  group('settleWolfHole — lone wolf', () {
    test('lone wolf win awards zero-sum points', () {
      const teeOrder = ['you', 'sam', 'alex', 'jordan'];
      const gross = {'you': 3, 'sam': 5, 'alex': 5, 'jordan': 6};
      const call = WolfCall(type: WolfCallType.lone);

      final result = settleWolfHole(
        teeOrder: teeOrder,
        wolfKey: 'you',
        call: call,
        grossByPlayer: gross,
        basis: WolfScoringBasis.gross,
        handicaps: const {},
        strokeIndex: null,
      );

      expect(result.winner, WolfHoleWinner.wolfSide);
      expect(result.pointsByPlayer['you'], 6);
      expect(result.pointsByPlayer['sam'], -2);
      expect(result.pointsByPlayer['alex'], -2);
      expect(result.pointsByPlayer['jordan'], -2);
      expect(result.pointsByPlayer.values.fold(0, (a, b) => a + b), 0);
    });

    test('lone wolf loss reverses zero-sum points', () {
      const teeOrder = ['you', 'sam', 'alex', 'jordan'];
      const gross = {'you': 6, 'sam': 3, 'alex': 4, 'jordan': 4};
      const call = WolfCall(type: WolfCallType.lone);

      final result = settleWolfHole(
        teeOrder: teeOrder,
        wolfKey: 'you',
        call: call,
        grossByPlayer: gross,
        basis: WolfScoringBasis.gross,
        handicaps: const {},
        strokeIndex: null,
      );

      expect(result.winner, WolfHoleWinner.fieldSide);
      expect(result.pointsByPlayer['you'], -6);
      expect(result.pointsByPlayer['sam'], 2);
      expect(result.pointsByPlayer['alex'], 2);
      expect(result.pointsByPlayer['jordan'], 2);
    });
  });

  group('settleWolfHole — blind wolf', () {
    test('blind wolf win awards +9 / -3 per opponent', () {
      const teeOrder = ['you', 'sam', 'alex', 'jordan'];
      const gross = {'you': 3, 'sam': 5, 'alex': 5, 'jordan': 6};
      const call = WolfCall(type: WolfCallType.blind);

      final result = settleWolfHole(
        teeOrder: teeOrder,
        wolfKey: 'you',
        call: call,
        grossByPlayer: gross,
        basis: WolfScoringBasis.gross,
        handicaps: const {},
        strokeIndex: null,
      );

      expect(result.winner, WolfHoleWinner.wolfSide);
      expect(result.pointsByPlayer['you'], 9);
      expect(result.pointsByPlayer['sam'], -3);
      expect(result.pointsByPlayer['alex'], -3);
      expect(result.pointsByPlayer['jordan'], -3);
    });
  });

  group('settleWolfHole — tie', () {
    test('tie awards zero', () {
      const teeOrder = ['you', 'sam', 'alex', 'jordan'];
      const gross = {'you': 4, 'sam': 4, 'alex': 4, 'jordan': 5};
      const call = WolfCall(type: WolfCallType.partner, partnerKey: 'sam');

      final result = settleWolfHole(
        teeOrder: teeOrder,
        wolfKey: 'you',
        call: call,
        grossByPlayer: gross,
        basis: WolfScoringBasis.gross,
        handicaps: const {},
        strokeIndex: null,
      );

      expect(result.winner, WolfHoleWinner.tie);
      expect(result.pointsByPlayer.values.every((p) => p == 0), isTrue);
    });
  });

  group('resolveStrokeIndexForHole', () {
    test('uses catalog map when present', () {
      expect(
        resolveStrokeIndexForHole(3, const {'3': 12}),
        12,
      );
    });

    test('falls back to standard template not hole number', () {
      expect(resolveStrokeIndexForHole(10, const {}), 12);
      expect(resolveStrokeIndexForHole(10, const {}), isNot(10));
    });

    test('hc 16 gets stroke on SI 12 hole but hc 4 does not', () {
      const si = 12;
      expect(strokesReceivedOnHole(courseHandicap: 16, strokeIndex: si), 1);
      expect(strokesReceivedOnHole(courseHandicap: 4, strokeIndex: si), 0);
    });
  });

  group('strokesReceivedOnHole', () {
    test('single and double stroke allocation', () {
      expect(strokesReceivedOnHole(courseHandicap: 12, strokeIndex: 5), 1);
      expect(strokesReceivedOnHole(courseHandicap: 36, strokeIndex: 5), 2);
      expect(strokesReceivedOnHole(courseHandicap: 4, strokeIndex: 10), 0);
    });

    test('plus handicap gives strokes on hardest holes', () {
      expect(strokesReceivedOnHole(courseHandicap: -2, strokeIndex: 1), -1);
      expect(strokesReceivedOnHole(courseHandicap: -2, strokeIndex: 2), -1);
      expect(strokesReceivedOnHole(courseHandicap: -2, strokeIndex: 5), 0);
    });

    test('formatCourseHandicap shows plus prefix for negative values', () {
      expect(formatCourseHandicap(-3), '+3');
      expect(formatCourseHandicap(12), '12');
    });

    test('formatExtraShotsLabel uses plain language', () {
      expect(formatExtraShotsLabel(0), 'No extra shots');
      expect(formatExtraShotsLabel(1), '1 extra shot');
      expect(formatExtraShotsLabel(2), '2 extra shots');
      expect(formatExtraShotsLabel(-1), '-1 extra shot');
      expect(formatExtraShotsLabel(-2), '-2 extra shots');
    });
  });

  group('auditWolfRound', () {
    test('validates stored hole results and totals', () {
      const teeOrder = ['you', 'sam', 'alex', 'jordan'];
      const holeOrder = [1, 2];
      final results = {
        1: WolfHoleResult(
          hole: 1,
          wolfKey: 'you',
          call: const WolfCall(type: WolfCallType.partner, partnerKey: 'sam'),
          grossByPlayer: const {'you': 4, 'sam': 4, 'alex': 5, 'jordan': 5},
          pointsByPlayer: const {'you': 2, 'sam': 2, 'alex': -2, 'jordan': -2},
        ),
        2: WolfHoleResult(
          hole: 2,
          wolfKey: 'sam',
          call: const WolfCall(type: WolfCallType.lone),
          grossByPlayer: const {'you': 5, 'sam': 3, 'alex': 5, 'jordan': 5},
          pointsByPlayer: const {'sam': 6, 'you': -2, 'alex': -2, 'jordan': -2},
        ),
      };

      final audit = auditWolfRound(
        holeOrder: holeOrder,
        teeOrder: teeOrder,
        wolfHoleResults: results,
        wolfPointsByPlayer: const {'you': 0, 'sam': 8, 'alex': -4, 'jordan': -4},
        basis: WolfScoringBasis.gross,
        handicaps: const {},
        holeStrokeIndexes: const {},
        holeCount: 18,
      );

      expect(audit.isValid, isTrue);
      expect(audit.holes, hasLength(2));
    });
  });
}
