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
      final points = const {
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
      expect(result.pointsByPlayer['you'], 1);
      expect(result.pointsByPlayer['sam'], 1);
      expect(result.pointsByPlayer['alex'], 0);
      expect(result.pointsByPlayer['jordan'], 0);
    });
  });

  group('settleWolfHole — lone wolf', () {
    test('lone wolf win doubles points', () {
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
      expect(result.pointsByPlayer['you'], 2);
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

  group('strokesReceivedOnHole', () {
    test('single and double stroke allocation', () {
      expect(strokesReceivedOnHole(courseHandicap: 12, strokeIndex: 5), 1);
      expect(strokesReceivedOnHole(courseHandicap: 36, strokeIndex: 5), 2);
      expect(strokesReceivedOnHole(courseHandicap: 4, strokeIndex: 10), 0);
    });
  });
}
