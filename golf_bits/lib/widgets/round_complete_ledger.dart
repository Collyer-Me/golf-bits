import 'package:flutter/material.dart';

import '../models/round_game_config.dart';
import '../models/round_settlement.dart';
import '../theme/app_theme.dart';
import 'outlined_surface_card.dart';
import 'player_avatar.dart';
import 'tally_marks.dart';

/// Horizontal Sand-accent winner banner for round complete.
class RoundCompleteWinnerBanner extends StatelessWidget {
  const RoundCompleteWinnerBanner({
    super.key,
    required this.hasWolf,
    required this.winnerName,
    required this.headlineMetric,
    required this.metricUnit,
    this.isCurrentUser = false,
  });

  final bool hasWolf;
  final String winnerName;
  final int headlineMetric;
  final String metricUnit;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final sand = AppTheme.sand(context);
    final capsLabel = hasWolf ? 'WOLF MATCH WINNER' : 'MOST BITS';
    final headline = hasWolf
        ? (isCurrentUser ? 'You take it' : '$winnerName takes it')
        : (isCurrentUser ? 'You clean up' : '$winnerName cleans up');
    final metricText = hasWolf
        ? '$headlineMetric'
        : (headlineMetric >= 0 ? '+$headlineMetric' : '$headlineMetric');
    final metricColor = hasWolf ? scheme.primary : AppTheme.bits(context);

    return Semantics(
      label: '$capsLabel, $winnerName, $metricText $metricUnit',
      child: OutlinedSurfaceCard(
        borderColor: sand.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space4,
          vertical: AppTheme.space4,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: sand,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.emoji_events_outlined, color: scheme.onSecondary, size: 24),
            ),
            SizedBox(width: AppTheme.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(capsLabel, style: AppTheme.monoLabel(context, color: sand)),
                  SizedBox(height: AppTheme.space1),
                  Text(
                    headline,
                    style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(metricText, style: AppTheme.score(context, size: 26, color: metricColor)),
                Text(
                  metricUnit,
                  style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One player row for the round-complete ledger.
class RoundCompleteLedgerRow {
  const RoundCompleteLedgerRow({
    required this.participantKey,
    required this.name,
    required this.colorIndex,
    this.wolfPoints = 0,
    this.bits = 0,
    required this.wolfDollars,
    required this.bitsDollars,
    required this.netDollars,
    this.isMatchWinner = false,
    this.onTap,
  });

  final String participantKey;
  final String name;
  final int colorIndex;
  final int wolfPoints;
  final int bits;
  final double wolfDollars;
  final double bitsDollars;
  final double netDollars;
  final bool isMatchWinner;
  final VoidCallback? onTap;
}

/// Format-aware standings ledger for round complete.
class RoundCompleteLedger extends StatelessWidget {
  const RoundCompleteLedger({
    super.key,
    required this.formats,
    required this.rows,
    required this.bitsPointValue,
    required this.wolfPointValue,
  });

  final List<RoundFormat> formats;
  final List<RoundCompleteLedgerRow> rows;
  final double bitsPointValue;
  final double wolfPointValue;

  bool get _hasWolf => roundHasWolf(formats);
  bool get _hasBits => roundHasBits(formats);
  bool get _combined => _hasWolf && _hasBits;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stakeNote = _combined
        ? '\$${wolfPointValue.toStringAsFixed(0)} / PT · \$${bitsPointValue.toStringAsFixed(0)} / BIT'
        : _hasWolf
            ? '\$${wolfPointValue.toStringAsFixed(0)} / PT'
            : '\$${bitsPointValue.toStringAsFixed(0)} / BIT';
    final headerLabel = _hasWolf && !_hasBits ? 'THE MATCH' : 'THE LEDGER';

    return OutlinedSurfaceCard(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space4,
        AppTheme.space4,
        AppTheme.space4,
        AppTheme.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  headerLabel,
                  style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
                ),
              ),
              Text(
                stakeNote,
                style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          _DashedDivider(color: scheme.outline),
          _HeaderRow(
            combined: _combined,
            hasWolf: _hasWolf,
            hasBits: _hasBits,
          ),
          for (var i = 0; i < rows.length; i++) ...[
            _DashedDivider(color: scheme.outlineVariant),
            _PlayerRow(
              row: rows[i],
              combined: _combined,
              hasWolf: _hasWolf,
              hasBits: _hasBits,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.combined,
    required this.hasWolf,
    required this.hasBits,
  });

  final bool combined;
  final bool hasWolf;
  final bool hasBits;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = AppTheme.monoLabel(context, color: scheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space2),
      child: Row(
        children: [
          Expanded(child: Text('PLAYER', style: label)),
          if (combined) ...[
            _pointsHeader('WOLF', AppTheme.bits(context), label),
            _pointsHeader('BITS', AppTheme.sand(context), label),
            _moneyHeader('NET', scheme.onSurface, label),
          ] else if (hasWolf) ...[
            SizedBox(
              width: 88,
              child: Text('POINTS', textAlign: TextAlign.right, style: label),
            ),
            _moneyHeader('SETTLE', scheme.onSurface, label),
          ] else if (hasBits) ...[
            SizedBox(
              width: 54,
              child: Text('BITS', textAlign: TextAlign.right, style: label.copyWith(color: AppTheme.sand(context))),
            ),
            _moneyHeader('SETTLE', scheme.onSurface, label),
          ],
        ],
      ),
    );
  }

  Widget _moneyHeader(String text, Color color, TextStyle base) {
    return SizedBox(
      width: 62,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: base.copyWith(color: color),
      ),
    );
  }

  Widget _pointsHeader(String text, Color color, TextStyle base) {
    return SizedBox(
      width: 52,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: base.copyWith(color: color),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.row,
    required this.combined,
    required this.hasWolf,
    required this.hasBits,
  });

  final RoundCompleteLedgerRow row;
  final bool combined;
  final bool hasWolf;
  final bool hasBits;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final settleAmount = combined ? row.netDollars : (hasWolf ? row.wolfDollars : row.bitsDollars);

    final content = Row(
      children: [
        Expanded(
          child: Row(
            children: [
              PlayerAvatar(displayName: row.name, colorIndex: row.colorIndex, size: 32),
              SizedBox(width: AppTheme.space25),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        row.name,
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (row.isMatchWinner) ...[
                      SizedBox(width: AppTheme.space1),
                      Icon(Icons.emoji_events_outlined, size: 13, color: AppTheme.sand(context)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (combined) ...[
          _pointsCell(row.wolfPoints, context, scheme.primary),
          _pointsCell(row.bits, context, AppTheme.sand(context)),
          _mainMoneyCell(settleAmount, context),
        ] else if (hasWolf) ...[
          SizedBox(
            width: 88,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TallyMarks(count: row.wolfPoints, height: 16, variant: TallyVariant.positive),
                SizedBox(width: AppTheme.space1),
                Text(
                  '${row.wolfPoints}',
                  style: AppTheme.score(context, size: 17, color: scheme.onSurface),
                ),
              ],
            ),
          ),
          _mainMoneyCell(settleAmount, context),
        ] else if (hasBits) ...[
          SizedBox(
            width: 54,
            child: Align(
              alignment: Alignment.centerRight,
              child: TallyMarks(
                count: row.bits,
                height: 16,
                variant: row.bits < 0 ? TallyVariant.penalty : TallyVariant.positive,
              ),
            ),
          ),
          _mainMoneyCell(settleAmount, context),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space25),
      child: row.onTap == null
          ? content
          : Semantics(
              button: true,
              label: '${row.name}, tap for breakdown',
              child: InkWell(
                onTap: row.onTap,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: content,
              ),
            ),
    );
  }

  Widget _pointsCell(int points, BuildContext context, Color color) {
    final scheme = Theme.of(context).colorScheme;
    final display = points >= 0 ? '+$points' : '$points';
    final textColor = points == 0
        ? scheme.onSurfaceVariant
        : points > 0
            ? color
            : AppTheme.junk(context);
    return SizedBox(
      width: 52,
      child: Text(
        display,
        textAlign: TextAlign.right,
        style: AppTheme.score(context, size: 17, color: textColor),
      ),
    );
  }

  Widget _mainMoneyCell(double amount, BuildContext context) {
    return SizedBox(
      width: 62,
      child: Text(
        formatSettlementMoney(amount, showSign: true),
        textAlign: TextAlign.right,
        style: AppTheme.score(context, size: 17, color: _moneyColor(context, amount)),
      ),
    );
  }

  Color _moneyColor(BuildContext context, double amount) {
    final scheme = Theme.of(context).colorScheme;
    if (amount.abs() < 0.005) return scheme.onSurfaceVariant;
    if (amount > 0) return AppTheme.bits(context);
    return AppTheme.junk(context);
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 4.0;
        const dashSpace = 4.0;
        final dashCount = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(decoration: BoxDecoration(color: color)),
            );
          }),
        );
      },
    );
  }
}
