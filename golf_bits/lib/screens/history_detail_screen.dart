import 'dart:async';

import 'package:flutter/material.dart';

import '../config/supabase_env.dart';
import '../data/history_repository.dart';
import '../models/history_round.dart';
import '../models/round_settlement.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/outlined_surface_card.dart';
import '../widgets/round_complete_ledger.dart';
import '../widgets/settle_up_panel.dart';
import 'player_breakdown_screen.dart';

/// Deep dive for one past round (ledger + settle-up). Refetches from Supabase when configured.
class HistoryDetailScreen extends StatefulWidget {
  const HistoryDetailScreen({super.key, required this.round});

  final HistoryRound round;

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  late HistoryRound _round;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _round = widget.round;
    unawaited(_refetchRound());
  }

  Future<void> _refetchRound() async {
    if (!SupabaseEnv.isConfigured) return;
    if (!mounted) return;
    setState(() => _refreshing = true);
    try {
      final fresh = await HistoryRepository.fetchRoundById(_round.id);
      if (mounted && fresh != null) setState(() => _round = fresh);
    } catch (_) {
      // Keep showing the list payload if refresh fails (offline / RLS).
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  List<String> _playerKeys() {
    final config = _round.gameConfig;
    if (config.teeOrder.isNotEmpty) return config.teeOrder;
    final keys = <String>{
      for (final s in _round.standings)
        if (s.participantKey != null && s.participantKey!.isNotEmpty) s.participantKey!,
      ..._round.wolfPointsByPlayer.keys,
    };
    return keys.toList();
  }

  Map<String, int> _colorIndexByKey() {
    final order = _playerKeys();
    return {for (var i = 0; i < order.length; i++) order[i]: i};
  }

  Map<String, int> _bitsForKey(String key) {
    for (final s in _round.standings) {
      if (s.participantKey == key) return s.bits;
    }
    return 0;
  }

  String? _wolfWinnerKey() {
    final name = _round.wolfWinnerName;
    if (name == null) return null;
    for (final k in _playerKeys()) {
      if (_round.displayNameForKey(k) == name) return k;
    }
    if (_round.wolfPointsByPlayer.isEmpty) return null;
    return _round.wolfPointsByPlayer.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  List<RoundCompleteLedgerRow> _ledgerRows({
    required Map<String, double> bitsNet,
    required Map<String, double> wolfNet,
    required Map<String, double> finalNet,
    required String? wolfWinnerKey,
  }) {
    final keys = _playerKeys();
    final config = _round.gameConfig;
    final rows = [
      for (final key in keys)
        RoundCompleteLedgerRow(
          participantKey: key,
          name: _round.displayNameForKey(key),
          colorIndex: _colorIndexByKey()[key] ?? 0,
          wolfPoints: _round.wolfPointsByPlayer[key] ?? 0,
          bits: _bitsForKey(key),
          wolfDollars: wolfNet[key] ?? 0,
          bitsDollars: bitsNet[key] ?? 0,
          netDollars: finalNet[key] ?? 0,
          isMatchWinner: wolfWinnerKey != null && key == wolfWinnerKey,
          onTap: config.hasBits
              ? () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => PlayerBreakdownScreen(
                        roundId: _round.id,
                        playerName: _round.displayNameForKey(key),
                        participantKey: key,
                        courseShortTitle: _round.courseShortTitle,
                        dateHeader: _round.dateHeader,
                        strokeByHole: _round.strokeByHole,
                        holePars: _round.holePars,
                        grossByPlayer: _round.grossByPlayer,
                      ),
                    ),
                  );
                  await _refetchRound();
                }
              : null,
        ),
    ];
    if (config.hasWolf && _round.wolfPointsByPlayer.isNotEmpty) {
      rows.sort((a, b) => b.wolfPoints.compareTo(a.wolfPoints));
    } else if (config.hasBits) {
      rows.sort((a, b) => b.bits.compareTo(a.bits));
    }
    return rows;
  }

  String? _evenMoneyMessage(Map<String, double> finalNet, String? wolfWinnerKey) {
    final config = _round.gameConfig;
    if (!config.hasWolf || !config.hasBits || wolfWinnerKey == null) return null;
    final net = finalNet[wolfWinnerKey] ?? 0;
    if (net.abs() >= 0.01) return null;
    return '${_round.displayNameForKey(wolfWinnerKey)} settles even — match win, bits gave it back';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final config = _round.gameConfig;
    final playerKeys = _playerKeys();
    final bitsScores = {for (final k in playerKeys) k: _bitsForKey(k)};
    final wolfPoints = {for (final k in playerKeys) k: _round.wolfPointsByPlayer[k] ?? 0};

    final settlement = computeRoundSettlement(
      playerKeys: playerKeys,
      bitsByPlayer: bitsScores,
      wolfPointsByPlayer: wolfPoints,
      bitsPointValue: config.bitsPointValue,
      wolfPointValue: config.wolfPointValue,
      hasBits: config.hasBits,
      hasWolf: config.hasWolf,
    );

    final wolfWinnerKey = config.hasWolf ? _wolfWinnerKey() : null;
    final bannerHasWolf = config.hasWolf && wolfWinnerKey != null;
    final bannerWinnerName = bannerHasWolf && wolfWinnerKey != null
        ? _round.displayNameForKey(wolfWinnerKey)
        : _round.winnerName;
    final bannerMetric = bannerHasWolf
        ? (_round.wolfPointsByPlayer[wolfWinnerKey] ?? 0)
        : _round.winnerBits;

    return Scaffold(
      appBar: BrandAppBar(
        actions: [
          if (SupabaseEnv.isConfigured)
            IconButton(
              tooltip: 'Refresh',
              onPressed: _refreshing ? null : () => unawaited(_refetchRound()),
              icon: _refreshing
                  ? SizedBox(
                      width: AppTheme.iconDense,
                      height: AppTheme.iconDense,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onSurface,
                      ),
                    )
                  : const Icon(Icons.refresh),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refetchRound,
        child: ListView(
          padding: AppTheme.screenPadding,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: AppTheme.space4),
            Text(
              '${_round.courseShortTitle.toUpperCase()} · ${_round.dateHeader.toUpperCase()}',
              style: AppTheme.monoLabel(context, color: AppTheme.bits(context)),
            ),
            if (_round.hasWolf) ...[
              SizedBox(height: AppTheme.space2),
              Text(
                _round.formatLabel.toUpperCase(),
                style: AppTheme.monoLabel(context, color: AppTheme.sand(context)),
              ),
            ],
            Text(
              _round.completed ? 'Round complete' : 'Round in progress',
              style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: AppTheme.space4),
            RoundCompleteWinnerBanner(
              hasWolf: bannerHasWolf,
              winnerName: bannerWinnerName,
              headlineMetric: bannerMetric,
              metricUnit: bannerHasWolf ? 'PTS' : 'BITS',
              isCurrentUser: bannerWinnerName.toLowerCase() == 'you',
            ),
            SizedBox(height: AppTheme.space4),
            RoundCompleteLedger(
              formats: config.formats,
              rows: _ledgerRows(
                bitsNet: settlement.bitsNet,
                wolfNet: settlement.wolfNet,
                finalNet: settlement.finalNet,
                wolfWinnerKey: wolfWinnerKey,
              ),
              bitsPointValue: config.bitsPointValue,
              wolfPointValue: config.wolfPointValue,
            ),
            SizedBox(height: AppTheme.space4),
            SettleUpPanel(
              payments: settlement.payments,
              nameForKey: _round.displayNameForKey,
              colorIndexForKey: _colorIndexByKey(),
              evenMoneyMessage: _evenMoneyMessage(settlement.finalNet, wolfWinnerKey),
            ),
            if (_round.leftEarly.isNotEmpty) ...[
              SizedBox(height: AppTheme.space6),
              Text(
                'RETIRED EARLY',
                style: text.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: AppTheme.letterStepCaps,
                ),
              ),
              SizedBox(height: AppTheme.space3),
              ..._round.leftEarly.map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space2),
                  child: OutlinedSurfaceCard(
                    borderColor: scheme.outlineVariant,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space4,
                      vertical: AppTheme.space3,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.name,
                                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Left hole ${row.leftHole}',
                                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          row.bitsLabel,
                          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(height: AppTheme.space6),
            FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share round — coming soon')),
                );
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share Results'),
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom + AppTheme.space4),
          ],
        ),
      ),
    );
  }
}
