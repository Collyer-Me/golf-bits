import 'package:flutter/material.dart';

import '../models/round_settlement.dart';
import '../theme/app_theme.dart';
import 'outlined_surface_card.dart';
import 'player_avatar.dart';

/// Combined settle-up: payer → payee transfers with minimal payment count.
class SettleUpPanel extends StatelessWidget {
  const SettleUpPanel({
    super.key,
    this.header = 'SETTLE UP',
    required this.payments,
    required this.nameForKey,
    this.colorIndexForKey = const {},
    this.evenMoneyMessage,
    this.compact = false,
  });

  final String header;
  final List<SettlementPayment> payments;
  final String Function(String key) nameForKey;
  final Map<String, int> colorIndexForKey;
  final String? evenMoneyMessage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final sand = AppTheme.sand(context);
    final paymentNote = payments.isEmpty
        ? 'All square'
        : '${payments.length} payment${payments.length == 1 ? '' : 's'} clears it';

    return OutlinedSurfaceCard(
      borderColor: sand.withValues(alpha: 0.35),
      padding: EdgeInsets.all(compact ? AppTheme.space3 : AppTheme.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(header.toUpperCase(), style: AppTheme.monoLabel(context, color: sand)),
              const Spacer(),
              Text(
                paymentNote,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          if (payments.isEmpty && evenMoneyMessage == null) ...[
            SizedBox(height: AppTheme.space3),
            Text(
              'All square — no money owed',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          for (var i = 0; i < payments.length; i++) ...[
            if (i == 0) SizedBox(height: AppTheme.space3),
            if (i > 0)
              Divider(height: 1, color: scheme.surfaceContainerHighest),
            _TransferRow(
              fromName: nameForKey(payments[i].fromKey),
              toName: nameForKey(payments[i].toKey),
              fromColorIndex: colorIndexForKey[payments[i].fromKey] ?? 0,
              toColorIndex: colorIndexForKey[payments[i].toKey] ?? 0,
              amount: payments[i].amount,
              compact: compact,
            ),
          ],
          if (evenMoneyMessage != null) ...[
            SizedBox(height: AppTheme.space3),
            Divider(height: 1, color: scheme.surfaceContainerHighest),
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.space3),
              child: Text(
                evenMoneyMessage!,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({
    required this.fromName,
    required this.toName,
    required this.fromColorIndex,
    required this.toColorIndex,
    required this.amount,
    required this.compact,
  });

  final String fromName;
  final String toName;
  final int fromColorIndex;
  final int toColorIndex;
  final double amount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sand = AppTheme.sand(context);
    final avatarSize = compact ? 28.0 : 30.0;
    final amountSize = compact ? 18.0 : 20.0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? AppTheme.space2 : AppTheme.space25),
      child: Row(
        children: [
          PlayerAvatar(displayName: fromName, colorIndex: fromColorIndex, size: avatarSize),
          SizedBox(width: AppTheme.space2),
          Expanded(
            flex: 2,
            child: Text(
              fromName,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.arrow_forward, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          PlayerAvatar(displayName: toName, colorIndex: toColorIndex, size: avatarSize),
          SizedBox(width: AppTheme.space2),
          Expanded(
            flex: 2,
            child: Text(
              toName,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            formatSettlementMoney(amount),
            style: AppTheme.score(context, size: amountSize, color: sand),
          ),
        ],
      ),
    );
  }
}
