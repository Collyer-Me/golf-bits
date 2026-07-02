import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import '../data/history_repository.dart';
import '../data/round_session_store.dart';
import '../models/round_game_config.dart';
import '../models/round_result.dart';
import '../models/round_settlement.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/outlined_surface_card.dart';
import '../widgets/round_complete_ledger.dart';
import '../widgets/settle_up_panel.dart';
import 'player_breakdown_screen.dart';

/// End of round: winner banner, format-aware ledger, combined settle-up.
class RoundSummaryScreen extends StatefulWidget {
  const RoundSummaryScreen({
    super.key,
    this.result,
    this.wolfPointsByPlayer,
    this.wolfWinnerName,
    this.gameConfig,
  });

  /// When null, shows [RoundResult.previewDemo] (resume / preview entry points).
  final RoundResult? result;
  final Map<String, int>? wolfPointsByPlayer;
  final String? wolfWinnerName;
  final RoundGameConfig? gameConfig;

  @override
  State<RoundSummaryScreen> createState() => _RoundSummaryScreenState();
}

class _RoundSummaryScreenState extends State<RoundSummaryScreen> {
  bool _saving = false;

  RoundResult get _r => widget.result ?? RoundResult.previewDemo();

  Map<String, int> get _wolfPoints {
    final fromWidget = widget.wolfPointsByPlayer;
    if (fromWidget != null && fromWidget.isNotEmpty) return fromWidget;
    if (widget.result?.wolfPointsByPlayer.isNotEmpty == true) {
      return widget.result!.wolfPointsByPlayer;
    }
    return const {};
  }

  String? get _wolfWinnerName => widget.wolfWinnerName ?? widget.result?.wolfWinnerName;

  RoundGameConfig get _config => widget.gameConfig ?? _r.gameConfig;

  String _nameForKey(String key) {
    for (final s in _r.standings) {
      if (s.participantKey == key) return s.name;
    }
    for (final p in _r.participants) {
      if (p.key == key) return p.displayName;
    }
    return key;
  }

  Map<String, int> _colorIndexByKey() {
    final order = _playerKeys();
    return {for (var i = 0; i < order.length; i++) order[i]: i};
  }

  List<String> _playerKeys() {
    if (_config.teeOrder.isNotEmpty) return _config.teeOrder;
    if (_r.participants.isNotEmpty) {
      return _r.participants.map((p) => p.key).toList();
    }
    final keys = <String>{..._bitsScoresByKey().keys, ..._wolfPoints.keys};
    return keys.toList();
  }

  Map<String, int> _bitsScoresByKey() {
    final fromStandings = {
      for (final s in _r.standings)
        if (s.participantKey != null && s.participantKey!.isNotEmpty) s.participantKey!: s.bits,
    };
    if (fromStandings.isNotEmpty) return fromStandings;
    return {
      for (var i = 0; i < _r.standings.length; i++)
        'p$i': _r.standings[i].bits,
    };
  }

  int _bitsForKey(String key) {
    final direct = _bitsScoresByKey()[key];
    if (direct != null) return direct;
    for (final s in _r.standings) {
      if (s.participantKey == key) return s.bits;
    }
    return 0;
  }

  String _nameForStandingKey(String key) {
    if (_nameForKey(key) != key) return _nameForKey(key);
    final match = RegExp(r'^p(\d+)$').firstMatch(key);
    if (match != null) {
      final idx = int.tryParse(match.group(1)!);
      if (idx != null && idx < _r.standings.length) return _r.standings[idx].name;
    }
    return key;
  }

  String? _participantKeyForName(String name) {
    for (final p in _r.participants) {
      if (p.displayName == name) return p.key;
    }
    for (final s in _r.standings) {
      if (s.name == name) return s.participantKey;
    }
    return null;
  }

  String? _wolfWinnerKey() {
    final byName = _wolfWinnerName;
    if (byName != null) {
      final key = _participantKeyForName(byName);
      if (key != null) return key;
    }
    if (_wolfPoints.isEmpty) return null;
    return _wolfPoints.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  List<RoundCompleteLedgerRow> _ledgerRows({
    required Map<String, double> bitsNet,
    required Map<String, double> wolfNet,
    required Map<String, double> finalNet,
    required String? wolfWinnerKey,
  }) {
    final keys = _playerKeys();
    final rows = [
      for (final key in keys)
        RoundCompleteLedgerRow(
          participantKey: key,
          name: _nameForStandingKey(key),
          colorIndex: _colorIndexByKey()[key] ?? 0,
          wolfPoints: _wolfPoints[key] ?? 0,
          bits: _bitsForKey(key),
          wolfDollars: wolfNet[key] ?? 0,
          bitsDollars: bitsNet[key] ?? 0,
          netDollars: finalNet[key] ?? 0,
          isMatchWinner: wolfWinnerKey != null && key == wolfWinnerKey,
          onTap: _config.hasBits
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PlayerBreakdownScreen(
                        roundId: _r.roundId ?? '',
                        playerName: _nameForStandingKey(key),
                        participantKey: key.startsWith('p') ? null : key,
                        courseShortTitle: _r.courseShortTitle,
                        strokeByHole: _r.strokeByHole,
                        holePars: _r.holePars,
                        grossByPlayer: _r.grossByPlayer,
                      ),
                    ),
                  );
                }
              : null,
        ),
    ];

    if (_config.hasWolf && _wolfPoints.isNotEmpty) {
      rows.sort((a, b) => b.wolfPoints.compareTo(a.wolfPoints));
    } else if (_config.hasBits) {
      rows.sort((a, b) => b.bits.compareTo(a.bits));
    }
    return rows;
  }

  String? _evenMoneyMessage(Map<String, double> finalNet, String? wolfWinnerKey) {
    if (!_config.hasWolf || !_config.hasBits || wolfWinnerKey == null) return null;
    final net = finalNet[wolfWinnerKey] ?? 0;
    if (net.abs() >= 0.01) return null;
    final name = _nameForStandingKey(wolfWinnerKey);
    return '$name settles even — match win, bits gave it back';
  }

  Future<void> _backToHome() async {
    final live = widget.result;
    final loggedInUser = Supabase.instance.client.auth.currentUser;
    var mayNavigateHome =
        live == null || !SupabaseEnv.isConfigured || loggedInUser == null;

    if (!mayNavigateHome) {
      setState(() => _saving = true);
      try {
        final row = live.toInsertRow();
        final roundId = live.roundId;
        if (roundId != null && roundId.isNotEmpty) {
          await HistoryRepository.completeRound(roundId: roundId, row: row);
        }
        if (live.gameConfig.handicaps.isNotEmpty) {
          await HistoryRepository.syncHandicapsToProfiles(
            participants: live.participants,
            handicaps: live.gameConfig.handicaps,
          );
        }
        final savedRoundId = roundId ?? await HistoryRepository.saveCompletedRound(row);
        var bitLine = '';
        try {
          if (roundId == null || roundId.isEmpty) {
            await HistoryRepository.saveBitEventsForRound(savedRoundId, live.bitEvents);
          }
        } catch (e) {
          bitLine = ' Bit timeline not stored: $e';
        }
        if (mounted) {
          await RoundSessionStore.clearDraft();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Round saved to your history.$bitLine')),
          );
        }
        mayNavigateHome = true;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save round: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
    if (mounted && mayNavigateHome) {
      if (live != null && SupabaseEnv.isConfigured && loggedInUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Round not saved — guest cloud sync is not active. Try guest sync from History, or create an account.',
            ),
          ),
        );
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final r = _r;
    final config = _config;
    final liveResult = widget.result;
    final unsavedGuestRound = liveResult != null &&
        SupabaseEnv.isConfigured &&
        Supabase.instance.client.auth.currentSession == null;

    final playerKeys = _playerKeys();
    final bitsScores = {
      for (final k in playerKeys) k: _bitsForKey(k),
    };
    final wolfPoints = {
      for (final k in playerKeys) k: _wolfPoints[k] ?? 0,
    };

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
        ? _nameForStandingKey(wolfWinnerKey)
        : r.winnerName;
    final bannerMetric = bannerHasWolf
        ? (_wolfPoints[wolfWinnerKey] ?? 0)
        : r.winnerBits;
    final bannerUnit = bannerHasWolf ? 'PTS' : 'BITS';
    final isCurrentUserWinner = bannerWinnerName.toLowerCase() == 'you';

    final ledgerRows = _ledgerRows(
      bitsNet: settlement.bitsNet,
      wolfNet: settlement.wolfNet,
      finalNet: settlement.finalNet,
      wolfWinnerKey: wolfWinnerKey,
    );
    final evenMessage = _evenMoneyMessage(settlement.finalNet, wolfWinnerKey);

    return Scaffold(
      appBar: BrandAppBar(
        leading: IconButton(
          tooltip: 'Close',
          onPressed: _saving ? null : _backToHome,
          icon: const Icon(Icons.close),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: AppTheme.screenPadding,
              children: [
                if (unsavedGuestRound) ...[
                  OutlinedSurfaceCard(
                    borderColor: scheme.outlineVariant,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.cloud_off_outlined,
                          color: scheme.onSurfaceVariant,
                          size: AppTheme.iconInline,
                        ),
                        SizedBox(width: AppTheme.space3),
                        Expanded(
                          child: Text(
                            'Guest cloud sync is off, so this round will not appear in History. '
                            'Try guest sync from the History tab, or create an account.',
                            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppTheme.space4),
                ],
                Text(
                  '${r.courseShortTitle.toUpperCase()} · ${r.holeCount} HOLES',
                  style: AppTheme.monoLabel(context, color: AppTheme.bits(context)),
                ),
                Text(
                  r.completed ? 'Round complete' : 'Round in progress',
                  style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: AppTheme.space4),
                RoundCompleteWinnerBanner(
                  hasWolf: bannerHasWolf,
                  winnerName: bannerWinnerName,
                  headlineMetric: bannerMetric,
                  metricUnit: bannerUnit,
                  isCurrentUser: isCurrentUserWinner,
                ),
                SizedBox(height: AppTheme.space4),
                RoundCompleteLedger(
                  formats: config.formats,
                  rows: ledgerRows,
                  bitsPointValue: config.bitsPointValue,
                  wolfPointValue: config.wolfPointValue,
                ),
                SizedBox(height: AppTheme.space4),
                SettleUpPanel(
                  payments: settlement.payments,
                  nameForKey: _nameForStandingKey,
                  colorIndexForKey: _colorIndexByKey(),
                  evenMoneyMessage: evenMessage,
                ),
                if (r.leftEarly.isNotEmpty) ...[
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
                  ...r.leftEarly.map(
                    (e) => Padding(
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
                                    e.name,
                                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'Left hole ${e.leftHole}',
                                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              e.bitsLabel,
                              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: AppTheme.space6),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surface.withValues(alpha: 0),
                  scheme.surface,
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pageHorizontal,
                AppTheme.space2,
                AppTheme.pageHorizontal,
                AppTheme.space6,
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Share sheet — coming soon')),
                      );
                    },
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share'),
                  ),
                  SizedBox(width: AppTheme.space25),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _backToHome,
                      icon: _saving
                          ? SizedBox(
                              width: AppTheme.iconInline,
                              height: AppTheme.iconInline,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.home_outlined),
                      label: Text(_saving ? 'Saving…' : 'Back to Home'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
