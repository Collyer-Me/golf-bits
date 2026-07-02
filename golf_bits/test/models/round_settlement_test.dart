import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/models/round_settlement.dart';

void main() {
  const players = ['p1', 'p2', 'p3', 'p4'];

  group('computeBitsNet — shared-cost', () {
    test('matches documented bits example at two dollars per bit', () {
      final net = computeBitsNet(
        bitsByPlayer: const {'p1': 6, 'p2': 4, 'p3': 3, 'p4': -1},
        bitsPointValue: 2,
      );

      expect(net['p1'], closeTo(8, 0.01));
      expect(net['p2'], closeTo(2.67, 0.01));
      expect(net['p3'], closeTo(0, 0.01));
      expect(net['p4'], closeTo(-10.67, 0.01));
      expect(net.values.fold(0.0, (a, b) => a + b), closeTo(0, 0.01));
    });

    test('single player returns zero net', () {
      expect(
        computeBitsNet(bitsByPlayer: const {'a': 5}, bitsPointValue: 2),
        {'a': 0.0},
      );
    });

    test('empty map returns empty', () {
      expect(computeBitsNet(bitsByPlayer: const {}, bitsPointValue: 2), isEmpty);
    });
  });

  group('computeWolfNet', () {
    test('multiplies zero-sum points by wolf point value', () {
      final net = computeWolfNet(
        wolfPointsByPlayer: const {'p1': 4, 'p2': 2, 'p3': -3, 'p4': -3},
        wolfPointValue: 5,
      );
      expect(net['p1'], 20);
      expect(net['p2'], 10);
      expect(net['p3'], -15);
      expect(net['p4'], -15);
      expect(net.values.fold(0.0, (a, b) => a + b), 0);
    });
  });

  group('computeFinalNet', () {
    test('combines bits and wolf nets', () {
      final bitsNet = computeBitsNet(
        bitsByPlayer: const {'p1': 6, 'p2': 4, 'p3': 3, 'p4': -1},
        bitsPointValue: 2,
      );
      const wolfNet = {
        'p1': 20.0,
        'p2': 10.0,
        'p3': -15.0,
        'p4': -15.0,
      };
      final finalNet = computeFinalNet(
        bitsNet: bitsNet,
        wolfNet: wolfNet,
        hasBits: true,
        hasWolf: true,
        playerKeys: players,
      );

      expect(finalNet['p1'], closeTo(28, 0.01));
      expect(finalNet['p2'], closeTo(12.67, 0.01));
      expect(finalNet['p3'], closeTo(-15, 0.01));
      expect(finalNet['p4'], closeTo(-25.67, 0.01));
      expect(finalNet.values.fold(0.0, (a, b) => a + b), closeTo(0, 0.01));
    });
  });

  group('minimalTransfers', () {
    test('matches documented combined settlement', () {
      final bitsNet = computeBitsNet(
        bitsByPlayer: const {'p1': 6, 'p2': 4, 'p3': 3, 'p4': -1},
        bitsPointValue: 2,
      );
      const wolfNet = {
        'p1': 20.0,
        'p2': 10.0,
        'p3': -15.0,
        'p4': -15.0,
      };
      final finalNet = computeFinalNet(
        bitsNet: bitsNet,
        wolfNet: wolfNet,
        hasBits: true,
        hasWolf: true,
        playerKeys: players,
      );
      final payments = minimalTransfers(finalNet);

      expect(payments.length, 3);
      expect(
        payments,
        contains(const SettlementPayment(fromKey: 'p4', toKey: 'p1', amount: 25.67)),
      );
      expect(
        payments,
        contains(const SettlementPayment(fromKey: 'p3', toKey: 'p1', amount: 2.33)),
      );
      expect(
        payments,
        contains(const SettlementPayment(fromKey: 'p3', toKey: 'p2', amount: 12.67)),
      );

      final flow = settlementNetByPlayer(payments: payments, playerKeys: players);
      for (final k in players) {
        expect(flow[k], closeTo(finalNet[k]!, 0.02));
      }
    });

    test('all square returns no payments', () {
      expect(
        minimalTransfers(const {'a': 0, 'b': 0}),
        isEmpty,
      );
    });
  });

  group('computeRoundSettlement', () {
    test('bits-only round', () {
      final result = computeRoundSettlement(
        playerKeys: players,
        bitsByPlayer: const {'p1': 6, 'p2': 4, 'p3': 3, 'p4': -1},
        wolfPointsByPlayer: const {},
        bitsPointValue: 2,
        wolfPointValue: 5,
        hasBits: true,
        hasWolf: false,
      );
      expect(result.wolfNet, isEmpty);
      expect(result.bitsNet['p1'], closeTo(8, 0.01));
      expect(result.payments, isNotEmpty);
    });
  });

  group('formatSettlementMoney', () {
    test('formats whole dollars without decimals', () {
      expect(formatSettlementMoney(10), '\$10');
      expect(formatSettlementMoney(10.5), '\$10.50');
    });

    test('showSign prefixes positive and negative', () {
      expect(formatSettlementMoney(8, showSign: true), '+\$8');
      expect(formatSettlementMoney(-3.33, showSign: true), '−\$3.33');
      expect(formatSettlementMoney(0, showSign: true), '\$0');
    });
  });
}
