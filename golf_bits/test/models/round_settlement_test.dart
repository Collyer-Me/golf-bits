import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/models/round_settlement.dart';

void main() {
  group('computeLeaderSettlement', () {
    test('winner collects from each loser at unit value', () {
      final payments = computeLeaderSettlement(
        scoresByPlayer: const {'a': 5, 'b': 3, 'c': 1},
        unitValue: 2,
      );
      expect(payments.length, 2);
      expect(
        payments,
        contains(const SettlementPayment(fromKey: 'b', toKey: 'a', amount: 4)),
      );
      expect(
        payments,
        contains(const SettlementPayment(fromKey: 'c', toKey: 'a', amount: 8)),
      );
    });

    test('all tied returns no payments', () {
      expect(
        computeLeaderSettlement(
          scoresByPlayer: const {'a': 2, 'b': 2},
          unitValue: 2,
        ),
        isEmpty,
      );
    });

    test('splits payment across tied leaders', () {
      final payments = computeLeaderSettlement(
        scoresByPlayer: const {'a': 4, 'b': 4, 'c': 0},
        unitValue: 2,
      );
      expect(payments.length, 2);
      expect(
        payments,
        contains(const SettlementPayment(fromKey: 'c', toKey: 'a', amount: 4)),
      );
      expect(
        payments,
        contains(const SettlementPayment(fromKey: 'c', toKey: 'b', amount: 4)),
      );
    });
  });

  group('formatSettlementMoney', () {
    test('formats whole dollars without decimals', () {
      expect(formatSettlementMoney(10), '\$10');
      expect(formatSettlementMoney(10.5), '\$10.50');
    });
  });
}
