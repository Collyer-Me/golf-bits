import 'package:flutter/material.dart';

import '../models/history_round.dart';
import '../models/wolf_audit.dart';
import '../models/wolf_scoring.dart';
import '../theme/app_theme.dart';
import 'outlined_surface_card.dart';

/// Hole-by-hole Wolf scoring verification for a completed round.
class WolfHoleAuditPanel extends StatelessWidget {
  const WolfHoleAuditPanel({
    super.key,
    required this.round,
    required this.audit,
    required this.nameForKey,
  });

  final HistoryRound round;
  final WolfRoundAudit audit;
  final String Function(String key) nameForKey;

  String _callLabel(WolfCall call) {
    return switch (call.type) {
      WolfCallType.blind => 'Blind Wolf',
      WolfCallType.lone => 'Lone Wolf',
      WolfCallType.partner => 'Partner · ${nameForKey(call.partnerKey ?? '')}',
    };
  }

  String _pointsSummary(Map<String, int> points) {
    final entries = points.entries.where((e) => e.value != 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return '0 pts (tie)';
    return entries.map((e) => '${nameForKey(e.key)} ${e.value >= 0 ? '+' : ''}${e.value}').join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ok = audit.isValid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'WOLF SCORING CHECK',
          style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
        ),
        SizedBox(height: AppTheme.space2),
        OutlinedSurfaceCard(
          borderColor: ok ? scheme.primary.withValues(alpha: 0.45) : AppTheme.junk(context).withValues(alpha: 0.45),
          padding: const EdgeInsets.all(AppTheme.space3),
          child: Row(
            children: [
              Icon(
                ok ? Icons.check_circle_outline : Icons.error_outline,
                color: ok ? scheme.primary : AppTheme.junk(context),
              ),
              SizedBox(width: AppTheme.space2),
              Expanded(
                child: Text(
                  ok
                      ? 'All ${audit.holes.length} holes match current Wolf rules.'
                      : 'Mismatch found — review holes marked below.',
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppTheme.space3),
        for (final row in audit.holes) ...[
          OutlinedSurfaceCard(
            borderColor: row.isValid ? scheme.outlineVariant : AppTheme.junk(context).withValues(alpha: 0.5),
            padding: const EdgeInsets.all(AppTheme.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'HOLE ${row.hole}',
                      style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
                    ),
                    const Spacer(),
                    Icon(
                      row.isValid ? Icons.check : Icons.close,
                      size: 16,
                      color: row.isValid ? scheme.primary : AppTheme.junk(context),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.space1),
                Text(
                  'Wolf: ${nameForKey(row.expectedWolfKey)} · ${_callLabel(row.call)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (!row.wolfKeyMatch)
                  Text(
                    'Stored wolf was ${nameForKey(row.storedWolfKey)}',
                    style: text.bodySmall?.copyWith(color: AppTheme.junk(context)),
                  ),
                SizedBox(height: AppTheme.space1),
                Text(
                  'Expected: ${_pointsSummary(row.expectedPoints)}',
                  style: text.bodySmall,
                ),
                if (!row.pointsMatch)
                  Text(
                    'Stored: ${_pointsSummary(row.storedPoints)}',
                    style: text.bodySmall?.copyWith(color: AppTheme.junk(context)),
                  ),
                if (row.settlement.wolfBestBall != null && row.settlement.fieldBestBall != null)
                  Text(
                    'Best ball ${row.settlement.wolfBestBall} vs ${row.settlement.fieldBestBall}',
                    style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          SizedBox(height: AppTheme.space2),
        ],
        if (!audit.totalsMatch) ...[
          Text(
            'TOTALS MISMATCH',
            style: AppTheme.monoLabel(context, color: AppTheme.junk(context)),
          ),
          SizedBox(height: AppTheme.space1),
          for (final key in round.gameConfig.teeOrder)
            Text(
              '${nameForKey(key)}: stored ${audit.storedTotals[key] ?? 0} · expected ${audit.expectedTotals[key] ?? 0}',
              style: text.bodySmall,
            ),
        ],
      ],
    );
  }
}
