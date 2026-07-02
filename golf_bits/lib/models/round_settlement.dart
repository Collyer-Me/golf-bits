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

/// Leader settlement: each player below the leader pays
/// `(leaderScore − score) × unitValue` split across tied leaders.
List<SettlementPayment> computeLeaderSettlement({
  required Map<String, int> scoresByPlayer,
  required double unitValue,
}) {
  if (scoresByPlayer.isEmpty || unitValue <= 0) return [];
  final maxScore = scoresByPlayer.values.reduce((a, b) => a > b ? a : b);
  final leaders = [
    for (final e in scoresByPlayer.entries)
      if (e.value == maxScore) e.key,
  ];
  if (leaders.length == scoresByPlayer.length) return [];

  final lines = <SettlementPayment>[];
  for (final entry in scoresByPlayer.entries) {
    if (entry.value >= maxScore) continue;
    final total = (maxScore - entry.value) * unitValue;
    if (total <= 0) continue;
    if (leaders.length == 1) {
      lines.add(SettlementPayment(fromKey: entry.key, toKey: leaders.first, amount: total));
      continue;
    }
    final share = total / leaders.length;
    for (final leader in leaders) {
      lines.add(SettlementPayment(fromKey: entry.key, toKey: leader, amount: share));
    }
  }
  return lines;
}

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

String formatSettlementMoney(double amount) {
  final rounded = amount.roundToDouble();
  if ((amount - rounded).abs() < 0.005) {
    return '\$${rounded.toInt()}';
  }
  return '\$${amount.toStringAsFixed(2)}';
}
