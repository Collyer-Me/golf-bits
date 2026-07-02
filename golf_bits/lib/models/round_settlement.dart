import 'package:flutter/foundation.dart';

/// One directed payment: [fromKey] owes [toKey] [amount] dollars.
@immutable
class SettlementPayment {
  const SettlementPayment({
    required this.fromKey,
    required this.toKey,
    required this.amount,
  });

  final String fromKey;
  final String toKey;
  final double amount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettlementPayment &&
          fromKey == other.fromKey &&
          toKey == other.toKey &&
          amount == other.amount;

  @override
  int get hashCode => Object.hash(fromKey, toKey, amount);
}

/// Shared-cost bits net: each player earns their bits value minus an equal
/// share of all other players' bits values. See docs/GOLF_SETTLEMENT.md.
Map<String, double> computeBitsNet({
  required Map<String, int> bitsByPlayer,
  required double bitsPointValue,
}) {
  if (bitsByPlayer.isEmpty || bitsPointValue <= 0) return {};
  final n = bitsByPlayer.length;
  if (n <= 1) {
    return {for (final k in bitsByPlayer.keys) k: 0.0};
  }

  final bitsValues = {
    for (final e in bitsByPlayer.entries) e.key: e.value * bitsPointValue,
  };
  final totalBitsValue = bitsValues.values.fold(0.0, (a, b) => a + b);

  return {
    for (final e in bitsValues.entries)
      e.key: e.value - (totalBitsValue - e.value) / (n - 1),
  };
}

/// Wolf dollar net from accumulated zero-sum hole points.
Map<String, double> computeWolfNet({
  required Map<String, int> wolfPointsByPlayer,
  required double wolfPointValue,
}) {
  if (wolfPointsByPlayer.isEmpty || wolfPointValue <= 0) return {};
  return {
    for (final e in wolfPointsByPlayer.entries) e.key: e.value * wolfPointValue,
  };
}

/// Combined final net per player (bits + wolf).
Map<String, double> computeFinalNet({
  required Map<String, double> bitsNet,
  required Map<String, double> wolfNet,
  required bool hasBits,
  required bool hasWolf,
  required Iterable<String> playerKeys,
}) {
  final keys = playerKeys.toList();
  return {
    for (final k in keys)
      k: (hasBits ? (bitsNet[k] ?? 0) : 0) + (hasWolf ? (wolfNet[k] ?? 0) : 0),
  };
}

/// Greedy minimal transfers that clear all non-zero final nets.
/// Amounts are rounded to cents; any remainder is assigned to the largest debtor.
List<SettlementPayment> minimalTransfers(Map<String, double> finalNet) {
  if (finalNet.isEmpty) return [];

  final creditors = <String, double>{};
  final debtors = <String, double>{};
  for (final e in finalNet.entries) {
    final cents = _roundCents(e.value);
    if (cents > 0.005) {
      creditors[e.key] = cents;
    } else if (cents < -0.005) {
      debtors[e.key] = -cents;
    }
  }

  if (creditors.isEmpty && debtors.isEmpty) return [];

  _balanceRoundingRemainder(creditors, debtors, finalNet);

  final creditorList = creditors.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final debtorList = debtors.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final payments = <SettlementPayment>[];
  var ci = 0;
  var di = 0;
  while (ci < creditorList.length && di < debtorList.length) {
    final credit = creditorList[ci];
    final debt = debtorList[di];
    final amount = credit.value < debt.value ? credit.value : debt.value;
    if (amount > 0.005) {
      payments.add(
        SettlementPayment(
          fromKey: debt.key,
          toKey: credit.key,
          amount: _roundCents(amount),
        ),
      );
    }
    creditorList[ci] = MapEntry(credit.key, credit.value - amount);
    debtorList[di] = MapEntry(debt.key, debt.value - amount);
    if (creditorList[ci].value <= 0.005) ci++;
    if (debtorList[di].value <= 0.005) di++;
  }

  return payments;
}

void _balanceRoundingRemainder(
  Map<String, double> creditors,
  Map<String, double> debtors,
  Map<String, double> finalNet,
) {
  final creditorSum = creditors.values.fold(0.0, (a, b) => a + b);
  final debtorSum = debtors.values.fold(0.0, (a, b) => a + b);
  final diff = _roundCents(creditorSum - debtorSum);
  if (diff.abs() < 0.005) return;

  if (diff > 0 && debtors.isNotEmpty) {
    final largest = debtors.entries.reduce((a, b) => a.value >= b.value ? a : b);
    debtors[largest.key] = largest.value + diff;
  } else if (diff < 0 && creditors.isNotEmpty) {
    final largest = creditors.entries.reduce((a, b) => a.value >= b.value ? a : b);
    creditors[largest.key] = largest.value - diff;
  } else if (diff != 0) {
    // Fallback: adjust from raw finalNet largest magnitude player.
    String? target;
    var maxAbs = 0.0;
    for (final e in finalNet.entries) {
      final abs = e.value.abs();
      if (abs > maxAbs) {
        maxAbs = abs;
        target = e.key;
      }
    }
    if (target != null) {
      if (diff > 0 && debtors.containsKey(target)) {
        debtors[target] = debtors[target]! + diff;
      } else if (diff < 0 && creditors.containsKey(target)) {
        creditors[target] = creditors[target]! - diff;
      }
    }
  }
}

double _roundCents(double amount) => (amount * 100).roundToDouble() / 100;

/// Net cash flow per player from settlement lines (positive = collects).
Map<String, double> settlementNetByPlayer({
  required Iterable<SettlementPayment> payments,
  required Iterable<String> playerKeys,
}) {
  final out = {for (final k in playerKeys) k: 0.0};
  for (final p in payments) {
    out[p.fromKey] = (out[p.fromKey] ?? 0) - p.amount;
    out[p.toKey] = (out[p.toKey] ?? 0) + p.amount;
  }
  return out;
}

/// Totals collected by each winner (sum of incoming payments).
Map<String, double> settlementCollections(Iterable<SettlementPayment> payments) {
  final out = <String, double>{};
  for (final p in payments) {
    out[p.toKey] = (out[p.toKey] ?? 0) + p.amount;
  }
  return out;
}

String formatSettlementMoney(double amount, {bool showSign = false}) {
  final rounded = _roundCents(amount);
  final abs = rounded.abs();
  final sign = rounded < 0 ? '−' : (showSign && rounded > 0 ? '+' : '');
  if ((abs - abs.roundToDouble()).abs() < 0.005) {
    return '$sign\$${abs.toInt()}';
  }
  return '$sign\$${abs.toStringAsFixed(2)}';
}

/// Convenience: compute full round settlement from raw scores.
({
  Map<String, double> bitsNet,
  Map<String, double> wolfNet,
  Map<String, double> finalNet,
  List<SettlementPayment> payments,
}) computeRoundSettlement({
  required Iterable<String> playerKeys,
  required Map<String, int> bitsByPlayer,
  required Map<String, int> wolfPointsByPlayer,
  required double bitsPointValue,
  required double wolfPointValue,
  required bool hasBits,
  required bool hasWolf,
}) {
  final keys = playerKeys.toList();
  final bitsNet = hasBits
      ? computeBitsNet(bitsByPlayer: bitsByPlayer, bitsPointValue: bitsPointValue)
      : <String, double>{};
  final wolfNet = hasWolf
      ? computeWolfNet(
          wolfPointsByPlayer: wolfPointsByPlayer,
          wolfPointValue: wolfPointValue,
        )
      : <String, double>{};
  final finalNet = computeFinalNet(
    bitsNet: bitsNet,
    wolfNet: wolfNet,
    hasBits: hasBits,
    hasWolf: hasWolf,
    playerKeys: keys,
  );
  final payments = minimalTransfers(finalNet);
  return (bitsNet: bitsNet, wolfNet: wolfNet, finalNet: finalNet, payments: payments);
}
