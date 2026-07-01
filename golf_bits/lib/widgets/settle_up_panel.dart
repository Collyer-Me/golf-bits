import 'package:flutter/material.dart';

import '../models/round_settlement.dart';
import '../theme/app_theme.dart';
import 'outlined_surface_card.dart';
import 'player_avatar.dart';

/// Who owes who for a side game (bits or Wolf points).
class SettleUpPanel extends StatelessWidget {
  const SettleUpPanel({
    super.key,
    required this.header,
    required this.payments,
    required this.nameForKey,
    this.colorIndexForKey = const {},
  });

  final String header;
  final List<SettlementPayment> payments;
  final String Function(String key) nameForKey;
  final Map<String, int> colorIndexForKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final collections = settlementCollections(payments);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          header.toUpperCase(),
          style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
        ),
        SizedBox(height: AppTheme.space2),
        OutlinedSurfaceCard(
          borderColor: scheme.outlineVariant,
          child: payments.isEmpty
              ? Text(
                  'All square — no money owed',
                  style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < payments.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                      _PaymentRow(
                        fromName: nameForKey(payments[i].fromKey),
                        toName: nameForKey(payments[i].toKey),
                        amount: payments[i].amount,
                        colorIndex: colorIndexForKey[payments[i].fromKey] ?? 0,
                      ),
                    ],
                    for (final entry in collections.entries) ...[
                      Divider(height: 1, color: scheme.outlineVariant),
                      _CollectionRow(
                        name: nameForKey(entry.key),
                        amount: entry.value,
                        colorIndex: colorIndexForKey[entry.key] ?? 0,
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.fromName,
    required this.toName,
    required this.amount,
    required this.colorIndex,
  });

  final String fromName;
  final String toName;
  final double amount;
  final int colorIndex;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space2),
      child: Row(
        children: [
          PlayerAvatar(displayName: fromName, colorIndex: colorIndex, size: 30),
          SizedBox(width: AppTheme.space2),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: text.bodyMedium,
                children: [
                  TextSpan(text: '$fromName pays ', style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(
                    text: toName,
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.bits(context)),
                  ),
                ],
              ),
            ),
          ),
          Text(
            formatSettlementMoney(amount),
            style: AppTheme.score(context, size: 18),
          ),
        ],
      ),
    );
  }
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({
    required this.name,
    required this.amount,
    required this.colorIndex,
  });

  final String name;
  final double amount;
  final int colorIndex;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space2),
      child: Row(
        children: [
          PlayerAvatar(displayName: name, colorIndex: colorIndex, size: 30),
          SizedBox(width: AppTheme.space2),
          Expanded(
            child: Text(
              '$name collects',
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '+${formatSettlementMoney(amount)}',
            style: AppTheme.score(context, size: 18, color: AppTheme.bits(context)),
          ),
        ],
      ),
    );
  }
}
